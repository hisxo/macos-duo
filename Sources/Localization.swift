import Foundation

enum AppLanguage: String, CaseIterable {
    case system, en, fr

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if self != .system { return rawValue }
        // Match the first supported preference, including regional variants.
        for preference in preferredLanguages {
            let base = preference.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if base == "fr" { return "fr" }
            if base == "en" { return "en" }
        }
        return "en"
    }
}

enum Localization {
    static func text(_ key: String, language: AppLanguage) -> String {
        guard let pair = strings[key] else { return key }
        return language.resolved() == "fr" ? pair.fr : pair.en
    }

    static let strings: [String: (en: String, fr: String)] = [
        "Language": ("Language", "Langue"),
        "backward.title": ("Beyond the open position", "Au-delà de la position ouverte"),
        "backward.description": ("The effect returns gradually when you tilt the display farther back. Set intensity to 0% to disable it.", "L’effet revient progressivement lorsque l’écran s’incline vers l’arrière. Réglez l’intensité sur 0 % pour le désactiver."),
        "backward.start": ("Starts at", "Début à"),
        "backward.end": ("Maximum at", "Maximum à"),
        "backward.strength": ("Intensity", "Intensité"),
        "System": ("System default", "Langue du système"),
        "Lid animation": ("Lid animation", "Animation de l’écran"),
        "Launch at login": ("Launch at login", "Lancer à la connexion"),
        "Open MacOS Duo": ("Open MacOS Duo", "Ouvrir MacOS Duo"),
        "Preview on desktop": ("Preview on desktop", "Aperçu sur le bureau"),
        "Dismiss animation": ("Dismiss animation", "Masquer l’animation"),
        "Quit MacOS Duo": ("Quit MacOS Duo", "Quitter MacOS Duo"),
        "Overview": ("Overview", "Vue d’ensemble"),
        "MOTION, MADE PHYSICAL": ("MOTION, MADE PHYSICAL", "LE MOUVEMENT PREND VIE"),
        "A little magic in\nevery open and close.": ("A little magic in\nevery open and close.", "Un peu de magie à chaque ouverture et fermeture."),
        "Preview mode": ("Preview mode", "Mode aperçu"),
        "Live hinge angle": ("Live hinge angle", "Angle en temps réel"),
        "Make the everyday fluid.": ("Make the everyday fluid.", "Un quotidien plus fluide."),
        "The Duo fold effect, reimagined for your Mac.": ("The Duo fold effect, reimagined for your Mac.", "L’effet de pliage Duo, réinventé pour votre Mac."),
        "Enabled": ("Enabled", "Activé"),
        "MOTION PREVIEW": ("MOTION PREVIEW", "APERÇU DE L’ANIMATION"),
        "OPEN": ("OPEN", "OUVERT"),
        "CLOSED": ("CLOSED", "FERMÉ"),
        "IN MOTION": ("IN MOTION", "EN MOUVEMENT"),
        "Preview lid angle": ("Preview lid angle", "Angle de l’écran dans l’aperçu"),
        "Play close and open cycle": ("Play close and open cycle", "Lire un cycle de fermeture et d’ouverture"),
        "Tune the feeling": ("Tune the feeling", "Ajuster l’animation"),
        "Reset": ("Reset", "Réinitialiser"),
        "reset.help": ("Restore animation defaults without changing macOS permissions, language, or launch at login.", "Rétablir les réglages de l’animation sans modifier les autorisations macOS, la langue ni le lancement à la connexion."),
        "Begin folding": ("Begin folding", "Début de l’animation"),
        "Animation start angle": ("Animation start angle", "Angle de début de l’animation"),
        "Frosted glass": ("Frosted glass", "Verre dépoli"),
        "Frost intensity": ("Frost intensity", "Intensité du flou"),
        "Your screen in motion": ("Your screen in motion", "Votre écran en mouvement"),
        "Choose my screen": ("Choose my screen", "Choisir mon écran"),
        "Checking…": ("Checking…", "Vérification…"),
        "Verify": ("Verify", "Vérifier"),
        "macOS Settings": ("macOS Settings", "Réglages macOS"),
        "Test effect": ("Test effect", "Tester l’effet"),
        "Preview follows physical lid": ("Preview follows physical lid", "L’aperçu suit l’écran physique"),
        "ESC TO DISMISS": ("ESC TO DISMISS", "ÉCHAP POUR MASQUER"),
        "footer": ("Runs from the menu bar. Opening transitions require an unlocked session.", "Fonctionne dans la barre des menus. L’ouverture nécessite une session déverrouillée."),
        "ready": ("Ready. Move the slider to explore the effect.", "Prêt. Déplacez le curseur pour explorer l’effet."),
        "capture.authorize": ("Allow screen access", "Autoriser l’écran"),
        "capture.restart": ("Restart MacOS Duo", "Redémarrer MacOS Duo"),
        "capture.restarting": ("Restarting…", "Redémarrage…"),
        "capture.checking": ("Checking screen access…", "Vérification de l’accès à l’écran…"),
        "capture.details": ("Technical details", "Détails techniques"),
        "capture.restartFailed": ("Could not restart. Quit with Command-Q and reopen this app.", "Redémarrage impossible. Quittez avec ⌘Q puis rouvrez cette app."),
        "capture.choose": ("Allow access, enable MacOS Duo in Settings, then restart. Your built-in display is selected automatically.", "Autorisez l’accès, activez MacOS Duo dans les Réglages, puis redémarrez. L’écran intégré est choisi automatiquement."),
        "capture.confirm": ("Select the built-in display in the macOS picker and confirm sharing.", "Sélectionnez l’écran intégré dans le sélecteur macOS et confirmez le partage."),
        "capture.settings": ("Enable MacOS Duo under Screen & System Audio Recording. Then return here and click Restart MacOS Duo (unless macOS already restarted it).", "Activez MacOS Duo dans Enregistrement de l’écran et de l’audio système. Revenez ensuite cliquer sur Redémarrer MacOS Duo, sauf si macOS l’a déjà relancée."),
        "capture.verified": ("Capture verified: the preview now uses your screen.", "Capture vérifiée : l’aperçu utilise maintenant votre écran."),
        "capture.failed": ("Screen access could not be verified. Automatic effects are paused. Allow access again, check this copy of MacOS Duo in Settings, then restart.", "L’accès à l’écran n’a pas pu être vérifié. L’effet automatique est suspendu. Autorisez à nouveau l’accès, vérifiez cette copie de MacOS Duo dans les Réglages, puis redémarrez."),
        "capture.cancelled": ("Selection cancelled. Choose your screen to try again.", "Sélection annulée. Choisissez votre écran pour réessayer."),
        "capture.pickerFailed": ("The screen picker could not open.", "Le sélecteur d’écran n’a pas pu s’ouvrir."),
        "capture.required": ("Screen access is not enabled. Allow access, enable MacOS Duo in Settings, then restart.", "L’accès à l’écran n’est pas activé. Autorisez l’accès, activez MacOS Duo dans les Réglages, puis redémarrez."),
        "reset.done": ("Defaults restored: 75° threshold, 100% frost, animation enabled.", "Réglages réinitialisés : seuil 75°, flou 100 %, animation activée."),
        "login.approval": ("Allow MacOS Duo in System Settings → General → Login Items.", "Autorisez MacOS Duo dans Réglages Système → Général → Ouverture."),
        "login.failed": ("The login item could not be updated.", "Le lancement à la connexion n’a pas pu être modifié."),
        "preview.desktop": ("Desktop preview · press Escape to dismiss.", "Aperçu sur le bureau · appuyez sur Échap pour masquer."),
        "preview.playing": ("Playing a complete close and open cycle.", "Lecture d’un cycle complet de fermeture et d’ouverture."),
        "effect.failed": ("The effect could not be prepared.", "L’effet n’a pas pu être préparé."),
        "sensor.connected": ("Lid sensor connected", "Capteur d’angle connecté"),
        "sensor.unavailable": ("No compatible lid sensor · preview available", "Aucun capteur compatible · aperçu disponible"),
        "startup.failed": ("MacOS Duo could not start", "MacOS Duo n’a pas pu démarrer"),
        "metal.unavailable": ("Metal is unavailable on this Mac.", "Metal n’est pas disponible sur ce Mac."),
        "metal.allocation": ("Could not allocate the image blur textures.", "Impossible d’allouer les textures du flou."),
        "display.missing": ("Display not found.", "Écran introuvable.")
    ]

    static var savedLanguage: AppLanguage {
        if CommandLine.arguments.contains("--ui-test"),
           let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--test-language=") }),
           let language = AppLanguage(rawValue: String(argument.dropFirst("--test-language=".count))) { return language }
        return AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "system") ?? .system
    }
}
