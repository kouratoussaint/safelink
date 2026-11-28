package com.fasosoft.safelink

import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build

/**
 * Description d'un texte reçu, transmise telle quelle à l'interface Flutter
 * (canaux `share` et `quick`). Toutes les décisions sont prises côté Dart.
 *
 * Champs : `source` (`share`, `selection` ou `clipboard`), `type` (type
 * MIME annoncé), `text` (texte, borné à [MAX_TEXT] caractères),
 * `truncated` (texte coupé), `files` (des fichiers accompagnaient le
 * partage : ils ne sont jamais ouverts), `unreadable` (contenu illisible),
 * `sensitive` (texte copié marqué secret : non lu).
 *
 * Le texte n'est jamais écrit dans les journaux.
 */
internal object SharedPayload {
    /**
     * Longueur maximale transmise à l'interface. Elle dépasse la taille
     * d'un message analysable (10 000 caractères) pour que les liens d'un
     * long texte restent repérables.
     */
    const val MAX_TEXT = 100_000

    fun text(
        source: String,
        type: String?,
        text: String?,
        files: Boolean = false,
        sensitive: Boolean = false,
    ): Map<String, Any?> = mapOf(
        "source" to source,
        "type" to type,
        "text" to text?.take(MAX_TEXT),
        "truncated" to (text != null && text.length > MAX_TEXT),
        "files" to files,
        "unreadable" to false,
        "sensitive" to sensitive,
    )

    fun unreadable(source: String): Map<String, Any?> = mapOf(
        "source" to source,
        "type" to null,
        "text" to null,
        "truncated" to false,
        "files" to false,
        "unreadable" to true,
        "sensitive" to false,
    )

    /**
     * Lit le texte copié, une seule fois (`source` = `clipboard`). À
     * appeler quand la fenêtre de SafeLink a le focus : Android 10 et
     * suivants ne le permettent qu'à ce moment-là. Un contenu marqué secret
     * par Android 13 et suivants (mot de passe, code) n'est pas lu.
     */
    fun clipboard(context: Context): Map<String, Any?> = try {
        val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val description = manager.primaryClipDescription
        val sensitive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            description?.extras?.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE) == true
        if (sensitive) {
            text("clipboard", null, null, sensitive = true)
        } else {
            val clip = manager.primaryClip
            val text = if (clip != null && clip.itemCount > 0) {
                clip.getItemAt(0).coerceToText(context)?.toString()
            } else {
                null
            }
            text("clipboard", description?.getMimeType(0), text)
        }
    } catch (e: RuntimeException) {
        unreadable("clipboard")
    }
}
