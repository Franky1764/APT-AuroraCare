"""Pruebas sin red: python -m unittest backend.test_scoring."""
import copy
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from backend.scoring import calcular_tendencia, clasificar_senal, normalizar, score_memorice

try:
    from fastapi.testclient import TestClient
    from backend.main import app
except ImportError:
    TestClient = None


class ScoringTests(unittest.TestCase):
    def test_ejemplo_documentado(self):
        self.assertEqual(score_memorice(dict(errores=4, intentos=20, tiempo_total_seg=180, tasa_acierto_pct=60), 1), 55.8)

    def test_extremos_tres_niveles(self):
        for nivel, intentos, tiempo, errores_peor, intentos_peor, tiempo_peor in [(1,12,60,15,30,240),(2,16,80,20,40,300),(3,20,100,25,50,360)]:
            self.assertEqual(score_memorice(dict(errores=0,intentos=intentos,tiempo_total_seg=tiempo,tasa_acierto_pct=100),nivel),100)
            self.assertEqual(score_memorice(dict(errores=errores_peor,intentos=intentos_peor,tiempo_total_seg=tiempo_peor,tasa_acierto_pct=0),nivel),0)
        self.assertEqual(normalizar(-1,0,15),100)
        self.assertEqual(normalizar(200,0,15),0)

    def test_tendencias(self):
        self.assertEqual(calcular_tendencia([85,82,79,76,73,70,67,64]),dict(senal="revisar",variacion_pct=-28.2))
        self.assertEqual(calcular_tendencia([70]*5),dict(senal="estable",variacion_pct=0.0))
        self.assertEqual(calcular_tendencia([0]*5),dict(senal="estable",variacion_pct=0.0))
        self.assertEqual(calcular_tendencia([70]*4),dict(senal="insuficiente",variacion_pct=None))

    def test_umbrales_sin_redondear(self):
        for v, senal in [(5,"estable"),(5.001,"mejora"),(-5,"estable"),(-5.001,"atencion"),(-15,"atencion"),(-15.001,"revisar")]:
            self.assertEqual(clasificar_senal(v),senal)
        for variacion, senal in [(5.001,"mejora"),(-5.001,"atencion"),(-15.001,"revisar")]:
            scores = [50 + (i-2)*variacion/8 for i in range(5)]
            self.assertEqual(calcular_tendencia(scores)["senal"],senal)


@unittest.skipIf(TestClient is None, "FastAPI/TestClient no disponibles")
class EndpointTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.openai = patch("backend.data.openai_report_writer.AsyncOpenAI", side_effect=AssertionError("OpenAI no debe inicializarse"))
        self.openai.start()
        self.addCleanup(self.openai.stop)
        self.now = datetime(2026,10,28,12,tzinfo=timezone.utc)
        self.payload = dict(game_type="memorice_clasico",nivel=1,timestamp=self.now.isoformat(),
                            metricas=dict(errores=4,intentos=20,tiempo_total_seg=180,tasa_acierto_pct=60),historial_28d=[])

    def history(self, days, nivel=1, score=70, **extra):
        return dict(timestamp=(self.now-timedelta(days=days)).isoformat(), nivel=nivel, score=score,
                    **{'game_type': 'memorice_clasico', **extra})

    def post(self, payload=None):
        return self.client.post('/session/analyze',json=self.payload if payload is None else payload)

    def test_health_and_contract_without_openai(self):
        self.assertEqual(self.client.get('/health').json(),dict(status="OK"))
        self.payload['session_uuid']='ignored'
        response = self.post()
        self.assertEqual(response.status_code,200)
        self.assertEqual(response.json(),dict(score_sesion=55.8,nivel_jugado=1,sugerir_avance=False,sesiones_en_ventana=1,
                         scoring_version="scoring-v1.1-memorice-1",tendencia=dict(senal="insuficiente",variacion_pct=None,nivel_senal=1,ventana_dias=28)))

    def test_validation(self):
        cases = [('game_type','unknown'),('nivel',0),('nivel',4),('nivel',True),('timestamp','2026-10-28T12:00:00'),('metricas',dict(tasa_error_pct=20,tiempo_respuesta_ms=200,alcance=3))]
        for field,value in cases:
            with self.subTest(field=field,value=value):
                payload=copy.deepcopy(self.payload);payload[field]=value
                self.assertEqual(self.post(payload).status_code,422)
        for field,value in [('errores',-1),('intentos',1.5),('tiempo_total_seg',-1),('tasa_acierto_pct',101),('nombre','PII')]:
            payload=copy.deepcopy(self.payload);payload['metricas'][field]=value
            self.assertEqual(self.post(payload).status_code,422)
        for extra in [dict(session_uuid='identity'),dict(email='identity'),dict(game_type='toca_correcto'),dict(score=101),dict(timestamp='2026-10-20T12:00:00')]:
            self.payload['historial_28d']=[{**self.history(1),**extra}]
            self.assertEqual(self.post().status_code,422)

    def test_pending_games(self):
        from backend.scoring import GAME_DOMAINS
        metrics={'memoria':self.payload['metricas'],'atencion':dict(tasa_error_pct=10,tiempo_respuesta_ms=100,alcance=4),'praxias':dict(precision_pct=80,correcciones=2,tiempo_seg=30)}
        for game,domain in GAME_DOMAINS.items():
            if game=='memorice_clasico': continue
            payload={**self.payload,'game_type':game,'metricas':metrics[domain]}
            response=self.post(payload)
            self.assertEqual(response.status_code,422)
            self.assertEqual(response.json()['detail']['code'],'calibration_pending')

    def test_window_order_and_dominant_level(self):
        self.payload['historial_28d']=[self.history(1,2,64),self.history(28,2,85),self.history(4,2,70),self.history(8,2,76),self.history(12,2,82),self.history(29,2,100),self.history(-1,2,100)]
        result=self.post().json()
        self.assertEqual(result['sesiones_en_ventana'],6)
        self.assertEqual(result['tendencia']['nivel_senal'],2)
        self.assertEqual(result['tendencia']['senal'],'revisar')
        self.payload['historial_28d']=[self.history(1,2),self.history(2,2),self.history(3,1)]
        self.assertEqual(self.post().json()['tendencia']['nivel_senal'],1)
        self.payload['historial_28d']=[self.history(i) for i in range(1,5)]
        self.assertNotEqual(self.post().json()['tendencia']['senal'],'insuficiente')

    def test_trend_excludes_different_and_unknown_games(self):
        self.payload['historial_28d'] = [
            self.history(1), self.history(2), self.history(3),
            self.history(4, game_type='que_cambio'),
            self.history(5, game_type=None),
        ]
        result = self.post().json()
        self.assertEqual(result['sesiones_en_ventana'], 4)
        self.assertEqual(result['tendencia']['senal'], 'insuficiente')

    def test_advancement_requires_accuracy_same_game_and_level(self):
        self.payload['metricas']['tasa_acierto_pct']=70
        self.payload['historial_28d']=[self.history(i,game_type='memorice_clasico',tasa_acierto_pct=70) for i in [2,1]]
        self.assertTrue(self.post().json()['sugerir_avance'])
        for change in [dict(tasa_acierto_pct=None),dict(tasa_acierto_pct=69.9),dict(game_type='que_cambio'),dict(game_type=None),dict(nivel=2)]:
            payload=copy.deepcopy(self.payload);payload['historial_28d'][1].update(change)
            self.assertFalse(self.post(payload).json()['sugerir_avance'])
        self.payload['nivel']=3
        for item in self.payload['historial_28d']: item['nivel']=3
        self.assertFalse(self.post().json()['sugerir_avance'])


if __name__ == '__main__':
    unittest.main()
