const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, query, where, writeBatch, serverTimestamp, Timestamp } = require('firebase/firestore');
let env;
const token = 'A'.repeat(43);
const second = 'B'.repeat(43);
const db = (uid) => env.authenticatedContext(uid).firestore();
async function seed(owner = 'adult', ageMinutes = null) {
  await env.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    for (const [uid, role] of [[owner, 'elder'], ['other-adult', 'elder'], ['caregiver', 'caregiver'], ['caregiver-b', 'caregiver']]) {
      await setDoc(doc(store, 'users', uid), {
        displayName: 'Persona de prueba', createdAt: Timestamp.fromMillis(1000),
        role, currentMode: role === 'elder' ? 3 : 0, consentGiven: false, consentDate: null,
      });
    }
    if (ageMinutes !== null) {
      await setDoc(doc(store, 'caregiver_invites', token), {
        adultUID: owner, createdAt: Timestamp.fromMillis(Date.now() - ageMinutes * 60000),
        validForSeconds: 600, epoch: 0, status: 'active', consentVersion: 'caregiver-link-v1',
      });
      await setDoc(doc(store, 'caregiver_invite_state', owner), {token});
    }
  });
}
async function create(code = token, extra = {}, actor = 'adult') {
  const store = db(actor), batch = writeBatch(store);
  batch.set(doc(store, 'caregiver_invites', code), {
    adultUID: actor, createdAt: serverTimestamp(), validForSeconds: 600,
    epoch: 0, status: 'active', consentVersion: 'caregiver-link-v1', ...extra,
  });
  batch.set(doc(store, 'caregiver_invite_state', actor), {token: code});
  return batch.commit();
}
async function redeem(actor = 'caregiver', code = token, epoch = 0) {
  const store = db(actor), batch = writeBatch(store);
  batch.update(doc(store, 'caregiver_invites', code), {status: 'used', usedBy: actor, usedAt: serverTimestamp()});
  batch.set(doc(store, 'caregiver_links', code), {
    adultUID: 'adult', caregiverUID: actor, epoch, linkedAt: serverTimestamp(), status: 'active',
  });
  batch.set(doc(store, 'caregiver_link_state', actor), {token: code});
  return batch.commit();
}
async function cancel(code = token) {
  const store = db('adult'), batch = writeBatch(store);
  const link = await getDoc(doc(store, 'caregiver_links', code));
  batch.update(doc(store, 'caregiver_invites', code), {status: 'cancelled'});
  if (link.exists()) batch.update(doc(store, 'caregiver_links', code), {status:'revoked'});
  batch.set(doc(store, 'caregiver_invite_state', 'adult'), {token:null});
  return batch.commit();
}
before(async () => { env = await initializeTestEnvironment({projectId: 'demo-auroracare-rules',
  firestore:{rules:readFileSync(resolve(__dirname,'../../firestore.rules'),'utf8')}}); });
beforeEach(async () => { await env.clearFirestore(); await seed(); });
after(async () => { await env?.cleanup(); });

test('generation and consumption share one record and create no cognitive mapping', async () => {
  await assertSucceeds(create());
  const generated = (await getDoc(doc(db('adult'),'caregiver_invites',token))).data();
  assert.equal(generated.validForSeconds,600);
  assert.equal(generated.createdAt instanceof Timestamp,true);
  assert.equal('adultUUID' in generated,false);
  assert.equal('uuid' in generated,false);
  await assertSucceeds(getDoc(doc(db('caregiver'),'caregiver_invites',token)));
  await assertSucceeds(redeem());
  const linked = (await getDoc(doc(db('caregiver'),'caregiver_links',token))).data();
  assert.deepEqual(Object.keys(linked).sort(),['adultUID','caregiverUID','epoch','linkedAt','status'].sort());
});
test('a used code cannot be consumed again', async () => {
  await create(); await redeem();
  await assertFails(redeem());
  await assertFails(redeem('caregiver-b'));
});
test('simultaneous consumers cannot both succeed', async () => {
  await create();
  const result=await Promise.allSettled([redeem(),redeem('caregiver-b')]);
  assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
});
test('creation time and lifetime cannot be forged by the device', async () => {
  await assertFails(create(token,{createdAt:Timestamp.fromMillis(Date.now()+3600000)}));
  await assertFails(create(token,{validForSeconds:7200}));
});
test('an expired invitation cannot be read or consumed by a caregiver', async () => {
  await seed('adult',11);
  await assertFails(getDoc(doc(db('caregiver'),'caregiver_invites',token)));
  await assertFails(redeem());
});
test('cancelled invitation cannot be consumed', async () => {
  await create(); await assertSucceeds(cancel());
  await assertFails(redeem());
});
test('replacement requires retiring the previous code', async () => {
  await create();
  await assertFails(create(second));
  await cancel();
  await assertSucceeds(create(second));
  await assertFails(redeem('caregiver',token));
  await assertSucceeds(redeem('caregiver',second));
});
test('owner can revoke the connection atomically', async () => {
  await create(); await redeem(); await assertSucceeds(cancel());
  const link=(await getDoc(doc(db('caregiver'),'caregiver_links',token))).data();
  assert.equal(link.status,'revoked');
});
test('clearing the pointer without revoking the connection is denied', async () => {
  await create(); await redeem();
  await assertFails(setDoc(doc(db('adult'),'caregiver_invite_state','adult'),{token:null}));
});
test('another adult cannot consume or cancel a code', async () => {
  await create();
  await assertFails(redeem('other-adult'));
  await assertFails(updateDoc(doc(db('other-adult'),'caregiver_invites',token),{status:'cancelled'}));
});
test('caregiver cannot generate invitations on behalf of an adult', async () => {
  await assertFails(create(token,{},'caregiver'));
  await assertFails(create(token,{adultUID:'other-adult'}));
});
test('personal mode cannot generate a code', async () => {
  await updateDoc(doc(db('adult'),'users','adult'),{currentMode:2,caregiverSharingEnabled:false,caregiverAccessEpoch:1});
  await assertFails(create());
});
test('an old access generation is rejected on redemption', async () => {
  await create();
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(),'users','adult'),{caregiverAccessEpoch:1});
  });
  await assertFails(redeem());
});
test('consumption must create both link and private pointer in the same commit', async () => {
  await create();
  await assertFails(updateDoc(doc(db('caregiver'),'caregiver_invites',token),{status:'used',usedBy:'caregiver',usedAt:serverTimestamp()}));
});
test('invites and links cannot contain UUIDs, names, emails or session data', async () => {
  for (const field of ['adultUUID','uuid','email','displayName','scoreSesion','metrics']) {
    await assertFails(create(token,{[field]:'not-allowed'}));
  }
});
test('listing invitations and links is prohibited even to their participants', async () => {
  await create(); await redeem();
  await assertFails(getDocs(collection(db('adult'),'caregiver_invites')));
  await assertFails(getDocs(collection(db('caregiver'),'caregiver_links')));
});


test('personal mode requires retiring the existing invitation and connection first', async () => {
  await create(); await redeem();
  const update={currentMode:2,caregiverSharingEnabled:false,caregiverAccessEpoch:1};
  await assertFails(updateDoc(doc(db('adult'),'users','adult'),update));
  await cancel();
  await assertSucceeds(updateDoc(doc(db('adult'),'users','adult'),update));
  await assertSucceeds(updateDoc(doc(db('adult'),'users','adult'),{currentMode:3}));
  await assertFails(redeem());
  await assertFails(updateDoc(doc(db('adult'),'caregiver_links',token),{status:'active'}));
});
test('other adults, other caregivers and unauthenticated clients cannot read a used invitation or link', async () => {
  await create(); await redeem();
  for(const client of [db('other-adult'),db('caregiver-b'),env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(client,'caregiver_invites',token)));
    await assertFails(getDoc(doc(client,'caregiver_links',token)));
  }
});
test('identity metadata cannot be copied into cognitive data', async () => {
  await assertSucceeds(setDoc(doc(db('adult'),'cognitive_profiles','test-profile'),{deviceId:'random-device',activeMode:3}));
  for(const field of ['adultUID','caregiverUID','ownerUID','authUID']) {
    await assertFails(updateDoc(doc(db('adult'),'cognitive_profiles','test-profile'),{[field]:'adult'}));
  }
});


test('returning to caregiver mode accepts only a fresh code of the new generation', async () => {
  await create(); await redeem(); await cancel();
  await updateDoc(doc(db('adult'),'users','adult'),{currentMode:2,caregiverSharingEnabled:false,caregiverAccessEpoch:1});
  await updateDoc(doc(db('adult'),'users','adult'),{currentMode:3});
  await assertSucceeds(create(second,{epoch:1}));
  await assertFails(redeem('caregiver',second,0));
  await assertSucceeds(redeem('caregiver',second,1));
  await assertFails(getDoc(doc(db('caregiver'),'users','adult')));
  await assertFails(getDoc(doc(db('adult'),'users','caregiver')));
});

test('only the linked caregiver can publish their own display name', async () => {
  await create();
  await redeem();
  const link = (uid) => doc(db(uid), 'caregiver_links', token);
  const name = { caregiverName: 'Persona de prueba' };
  await assertFails(updateDoc(link('adult'), name));
  await assertFails(updateDoc(link('caregiver-b'), name));
  await assertFails(updateDoc(link('caregiver'), { caregiverName: 'Otro nombre' }));
  await assertFails(updateDoc(link('caregiver'), { ...name, status: 'revoked' }));
  await assertSucceeds(updateDoc(link('caregiver'), name));
  assert.equal((await assertSucceeds(getDoc(link('adult')))).data().caregiverName, name.caregiverName);
  await assertSucceeds(cancel());
  await assertFails(updateDoc(link('caregiver'), name));
});

test('shared practice is limited to the linked caregiver and ends on revocation', async () => {
  await create(token, {consentVersion: 'caregiver-link-v2'});
  await redeem();
  const summary = (uid) => doc(db(uid), 'caregiver_summaries', token);
  const area = {count: 1, metric: 'accuracy', value: 75, total: 0,
    trend: 'insufficient', comparable: 0, level: null, average: null};
  const practicedAt = Timestamp.fromMillis(Date.now() - 60000);
  const empty = {...area, count: 0, metric: 'none', value: 0};
  const payload = {publishedAt: serverTimestamp(), lastPracticeAt: practicedAt,
    memoria: {...area, value: 55, latestGame: 'memorice_clasico', latestLevel: 1,
      latestAt: practicedAt, attempts: 20, errorsPct: null, figures: null,
      supports: null, comparisonGame: null, practiceDays: 0, firstScore: null, lastScore: null},
    atencion: empty, praxias: empty};
  await assertFails(setDoc(summary('caregiver'), payload));
  await assertFails(setDoc(summary('adult'), {...payload, uuid: 'private'}));
  await assertSucceeds(setDoc(summary('adult'), payload));
  const received = await assertSucceeds(getDoc(summary('caregiver')));
  assert.equal(received.data().memoria.count, 1);
  assert.equal(received.data().memoria.value, 55);
  await assertSucceeds(setDoc(summary('adult'), {
    ...payload,
    publishedAt: serverTimestamp(),
    memoria: {...payload.memoria, comparable: 1, level: 1, average: 60,
      comparisonGame: 'memorice_clasico', practiceDays: 1, firstScore: 60, lastScore: 60},
    atencion: {...payload.memoria, latestGame: 'toca_correcto', metric: 'response',
      value: 900, attempts: null, errorsPct: 10},
    praxias: {...payload.memoria, latestGame: 'trazado_guiado', metric: 'precision',
      value: 80, attempts: null, figures: 3, supports: 2},
  }));
  await assertFails(getDoc(summary('caregiver-b')));
  await assertSucceeds(cancel());
  await assertFails(getDoc(summary('caregiver')));
  await assertFails(setDoc(summary('adult'), payload));
});


test('ARCO solo lista y borra vínculos e invitaciones propios', async () => {
  await create(); await redeem();
  const adult = db('adult'), other = db('other-adult');
  await assertSucceeds(getDocs(query(collection(adult, 'caregiver_links'), where('adultUID', '==', 'adult'))));
  await assertFails(getDocs(collection(other, 'caregiver_links')));
  await assertFails(deleteDoc(doc(adult, 'caregiver_links', token)));
  await updateDoc(doc(adult, 'users', 'adult'), {deletionPending: true, consentGiven: false, consentDate: null});
  await assertFails(deleteDoc(doc(other, 'caregiver_links', token)));
  await assertSucceeds(deleteDoc(doc(adult, 'caregiver_links', token)));
  await assertSucceeds(deleteDoc(doc(adult, 'caregiver_invites', token)));
  await assertSucceeds(deleteDoc(doc(adult, 'caregiver_invite_state', 'adult')));
});

test('ARCO el cuidador elimina su resumen antes del vínculo', async () => {
  await create(); await redeem();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'caregiver_summaries', token), {test: true});
  });
  const caregiver = db('caregiver');
  await assertFails(deleteDoc(doc(caregiver, 'caregiver_summaries', token)));
  await updateDoc(doc(caregiver, 'users', 'caregiver'), {deletionPending: true, consentGiven: false, consentDate: null});
  const batch = writeBatch(caregiver);
  batch.delete(doc(caregiver, 'caregiver_summaries', token));
  batch.delete(doc(caregiver, 'caregiver_links', token));
  await assertSucceeds(batch.commit());
  await assertSucceeds(deleteDoc(doc(caregiver, 'caregiver_invites', token)));
  await assertSucceeds(deleteDoc(doc(caregiver, 'caregiver_link_state', 'caregiver')));
  await assertSucceeds(create(second));
});

test('ARCO una marca de historial eliminado rechaza escrituras atrasadas', async () => {
  const adult = db('adult');
  const profile = doc(adult, 'cognitive_profiles', 'random-profile');
  const session = doc(adult, 'cognitive_profiles', 'random-profile', 'sessions', 'one');
  await setDoc(profile, {privacyDeleted: true});
  await assertFails(setDoc(session, {uuid: 'random-profile'}));
  await assertFails(setDoc(profile, {activeMode: 2}));
  await assertSucceeds(setDoc(profile, {privacyDeleted: true}));
});

test('ARCO el consentimiento permanece retirado durante la eliminación', async () => {
  const adult = db('adult');
  await updateDoc(doc(adult, 'users', 'adult'), {deletionPending: true, consentGiven: false, consentDate: null});
  await assertFails(updateDoc(doc(adult, 'users', 'adult'), {consentGiven: true, consentDate: serverTimestamp()}));
});
