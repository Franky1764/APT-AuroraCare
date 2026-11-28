package com.example.aurora_care

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint

/** Informe estructurado: cada área conserva sus unidades y sus niveles. */
internal class ReportPdfWriter(private val pdf: PdfDocument) {
    private val purple = Color.rgb(70, 51, 133)
    private val pale = Color.rgb(242, 238, 250)
    private val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(39, 33, 62)
        textSize = 11.5f
    }
    private val bold = TextPaint(body).apply { typeface = Typeface.DEFAULT_BOLD }
    private val title = TextPaint(bold).apply { color = purple; textSize = 20f }
    private val small = TextPaint(body).apply { textSize = 10f }
    private lateinit var page: PdfDocument.Page
    private lateinit var canvas: Canvas
    private var pageNumber = 0
    private var y = 0f
    private val bottom = 724f
    private var sectionTitle = ""
    private val widths = listOf(137, 70, 55, 237)
    private val disclaimer = "Este reporte no constituye un diagnóstico médico. Consulte a un profesional de la salud para una evaluación completa."

    private fun layout(text: String, width: Int, paint: TextPaint = body): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(3f, 1f)
            .build()

    private fun draw(text: StaticLayout, x: Float, top: Float) {
        canvas.save()
        canvas.translate(x, top)
        text.draw(canvas)
        canvas.restore()
    }

    private fun finishPage() {
        val footer = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pale }
        canvas.drawRoundRect(40f, 744f, 555f, 800f, 8f, 8f, footer)
        draw(layout(disclaimer, 491, small), 52f, 754f)
        canvas.drawText("AuroraCare · Página $pageNumber", 48f, 821f, small)
        pdf.finishPage(page)
    }

    private fun startPage(continuation: Boolean = false) {
        if (pageNumber > 0) finishPage()
        pageNumber++
        page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
        canvas = page.canvas
        canvas.drawText("AuroraCare | Informe de prácticas", 48f, 44f, bold)
        val heading = layout(sectionTitle + if (continuation) " · continuación" else "", 499, title)
        draw(heading, 48f, 65f)
        y = 65f + heading.height + 18f
    }

    private fun paragraph(text: String, paint: TextPaint = body) {
        // Se pagina por líneas para conservar incluso observaciones largas.
        val block = layout(text, 499, paint)
        var line = 0
        while (line < block.lineCount) {
            if (y + block.getLineBottom(line) - block.getLineTop(line) > bottom) startPage(true)
            val top = block.getLineTop(line)
            var end = line + 1
            while (end < block.lineCount && y + block.getLineBottom(end) - top <= bottom) end++
            val height = block.getLineBottom(end - 1) - top
            canvas.save()
            canvas.clipRect(48f, y, 547f, y + height)
            canvas.translate(48f, y - top)
            block.draw(canvas)
            canvas.restore()
            y += height + 12f
            line = end
        }
    }

    private fun tableHeader() {
        val background = Paint().apply { color = purple }
        canvas.drawRect(48f, y, 547f, y + 34f, background)
        val white = TextPaint(bold).apply { color = Color.WHITE; textSize = 10.5f }
        var x = 48f
        listOf("Ejercicio", "Nivel", "Prácticas", "Resultados").forEachIndexed { index, text ->
            draw(layout(text, widths[index] - 16, white), x + 8f, y + 9f)
            x += widths[index]
        }
        y += 34f
    }

    private fun table(rows: List<Map<*, *>>) {
        tableHeader()
        rows.forEachIndexed { index, row ->
            val values = listOf("game", "level", "count", "results").map { row[it]?.toString() ?: "" }
            val cells = values.mapIndexed { column, value -> layout(value, widths[column] - 16, if (column == 0) bold else body) }
            val rowHeight = cells.maxOf { it.height }.toFloat() + 24f
            // Cada fila es un grupo resumido; nunca se corta entre páginas.
            if (y + rowHeight > bottom) {
                startPage(true)
                tableHeader()
            }
            val background = Paint().apply { color = if (index % 2 == 0) pale else Color.WHITE }
            canvas.drawRect(48f, y, 547f, y + rowHeight, background)
            var x = 48f
            cells.forEachIndexed { column, cell ->
                draw(cell, x + 8f, y + 12f)
                x += widths[column]
            }
            y += rowHeight
        }
        y += 16f
    }

    private fun chart(activity: Map<String, Int>) {
        if (activity.isEmpty()) return
        if (y + 146f > bottom) startPage(true)
        paragraph("Actividad por área · cantidad de prácticas", bold)
        val maximum = (activity.values.maxOrNull() ?: 0).coerceAtLeast(1)
        for (name in listOf("Memoria", "Atención", "Motricidad")) {
            val count = activity[name] ?: 0
            canvas.drawText("$name: $count", 48f, y + 12f, body)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = pale }
            canvas.drawRoundRect(185f, y, 547f, y + 14f, 5f, 5f, paint)
            paint.color = purple
            val width = 362f * count.coerceAtLeast(0) / maximum
            if (width > 0) canvas.drawRoundRect(185f, y, 185f + width, y + 14f, 5f, 5f, paint)
            y += 32f
        }
        y += 16f
    }

    fun write(sections: List<Map<String, Any>>, activity: Map<String, Int>) {
        sections.forEachIndexed { index, section ->
            sectionTitle = section["title"]?.toString() ?: "Resultados"
            startPage()
            paragraph(section["body"]?.toString() ?: "")
            if (index == 0) chart(activity)
            val rows = (section["rows"] as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()
            if (rows.isNotEmpty()) table(rows)
            section["context"]?.toString()?.let { paragraph(it) }
            section["note"]?.toString()?.let { paragraph(it, small) }
            section["observations"]?.toString()?.let {
                if (y + 65f > bottom) startPage(true)
                paragraph("Sus observaciones para la consulta", bold)
                paragraph(it)
            }
        }
        if (pageNumber > 0) finishPage()
    }
}
