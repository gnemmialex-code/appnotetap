//
//  Typography.swift
//  TapBack Command
//
//  Système typographique centralisé — 100 % police système Apple
//  (San Francisco / SF Pro). AUCUNE police externe, aucun .ttf.
//
//  Pourquoi `design: .default` ?
//  ----------------------------
//  En SwiftUI, `Font.system(...)` utilise toujours San Francisco :
//    • `.default`    → SF Pro (Text/Display, choisi AUTOMATIQUEMENT par iOS
//                      selon la taille optique : SF Pro Display ≥ 20 pt,
//                      SF Pro Text < 20 pt)
//    • `.rounded`    → SF Pro Rounded
//    • `.monospaced` → SF Mono
//
//  Pourquoi partir des styles sémantiques (`.largeTitle`, `.body`…) ?
//  ----------------------------------------------------------------
//  Les tailles Dynamic Type par défaut d'Apple valent exactement
//  34 / 28 / 22 / 20 / 17 / 16 / 15 / 13 / 12 pt — c.-à-d. la grille
//  demandée. En s'appuyant dessus, on obtient :
//    1. la bonne taille,
//    2. le bon variant optique (Display vs Text) géré par le système,
//    3. le support du Dynamic Type / accessibilité (texte qui grossit
//       avec les réglages utilisateur) — best practice HIG.
//
//  Usage :  Text("Titre").font(.tbcTitle)
//

import SwiftUI

extension Font {

    // MARK: - Titres (SF Pro Display — 28…34 pt)

    /// 34 pt · Bold — grands titres d'écran (rare, le plus fort).
    static var tbcLargeTitle: Font {
        .system(.largeTitle, design: .default, weight: .bold)
    }

    /// 28 pt · Semibold — titres de navigation / écrans principaux.
    static var tbcTitle: Font {
        .system(.title, design: .default, weight: .semibold)
    }

    // MARK: - Sous-titres (SF Pro Display — 20…22 pt)

    /// 22 pt · Semibold — sous-titres marqués, titres de section.
    static var tbcSubtitle: Font {
        .system(.title2, design: .default, weight: .semibold)
    }

    /// 20 pt · Medium — sous-titres secondaires.
    static var tbcSubtitleSmall: Font {
        .system(.title3, design: .default, weight: .medium)
    }

    // MARK: - En-têtes de contenu (SF Pro Text — 17 pt Semibold)

    /// 17 pt · Semibold — en-tête de carte / ligne, label important.
    static var tbcHeadline: Font {
        .system(.headline, design: .default) // .headline = 17 pt semibold
    }

    // MARK: - Texte courant (SF Pro Text — 15…17 pt)

    /// 17 pt · Regular — corps de texte, paragraphes.
    static var tbcBody: Font {
        .system(.body, design: .default)
    }

    /// 16 pt · Medium — texte de bouton, libellé mis en avant.
    static var tbcBodyMedium: Font {
        .system(.callout, design: .default, weight: .medium)
    }

    /// 15 pt · Regular — sous-titres, descriptions secondaires.
    static var tbcSubheadline: Font {
        .system(.subheadline, design: .default)
    }

    // MARK: - Petits labels (SF Pro Text — 12…13 pt)

    /// 13 pt · Medium — petits labels, métadonnées.
    static var tbcCaption: Font {
        .system(.footnote, design: .default, weight: .medium) // .footnote = 13 pt
    }

    /// 12 pt · Regular — mentions discrètes, horodatages.
    static var tbcCaptionSmall: Font {
        .system(.caption, design: .default) // .caption = 12 pt
    }
}

// MARK: - Sucre syntaxique pour appliquer une couleur de texte en un appel

extension View {
    /// Applique police + couleur en une fois (lisibilité des vues).
    func tbcText(_ font: Font, _ color: Color = Constants.Palette.primaryText) -> some View {
        self.font(font).foregroundStyle(color)
    }
}
