// ContentFilter.swift
import Foundation

struct ContentFilter {
    
    // MARK: - Word/Phrase Lists
    // Keep this list focused on severe profanity, hate slurs, and violent/sexual abuse terms.
    private static let blockedWords: Set<String> = [
        // Strong profanity / sexual profanity
        "fuck", "fucker", "fucking", "motherfucker",
        "shit", "bullshit", "dick", "cock", "pussy", "cunt",
        "bitch", "bastard", "slut", "whore", "twat",
        "wanker", "prick", "asshole", "jackass", "dumbass",

        // Self-harm / violence / abuse
        "rape", "rapist", "kill", "killing", "murder", "suicide",
        "selfharm", "self-harm", "lynch",

        // Hate slurs / severe identity-based abuse
        "nigger", "nigga", "faggot", "fag", "dyke", "tranny",
        "chink", "gook", "spic", "kike", "wetback", "paki",
        "raghead", "sandnigger", "coon", "jap"
    ]

    // Phrase patterns that are commonly used for hateful targeting.
    private static let blockedPhrases: [String] = [
        "go back to your country",
        "go back to where you came from",
        "dirty immigrant",
        "white power",
        "heil hitler",
        "gas the",
        "kill yourself"
    ]

    private static let leetMap: [Character: Character] = [
        "0": "o",
        "1": "i",
        "2": "z",
        "3": "e",
        "4": "a",
        "5": "s",
        "6": "g",
        "7": "t",
        "8": "b",
        "9": "g",
        "@": "a",
        "$": "s",
        "!": "i",
        "+": "t"
    ]
    
    // MARK: - Filter Method
    /// Checks if content contains inappropriate words
    /// - Parameter content: The text to check
    /// - Returns: Tuple with (containsBadWords, detectedWords)
    static func containsInappropriateContent(_ content: String) -> (contains: Bool, detectedWords: [String]) {
        let normalized = normalizeForMatching(content)
        let tokens = Set(normalized.split(separator: " ").map(String.init))
        let compact = normalized.replacingOccurrences(of: " ", with: "")

        var detectedWords: [String] = []

        for blocked in blockedWords {
            let normalizedBlocked = normalizeForMatching(blocked).replacingOccurrences(of: " ", with: "")
            guard !normalizedBlocked.isEmpty else { continue }

            if tokens.contains(normalizedBlocked) {
                detectedWords.append(blocked)
                continue
            }

            // Catch obfuscated variants like "f.u.c.k", "fuuuck", "n1gg3r", etc.
            if normalizedBlocked.count >= 4 && compact.contains(normalizedBlocked) {
                detectedWords.append(blocked)
                continue
            }
        }

        for phrase in blockedPhrases {
            let normalizedPhrase = normalizeForMatching(phrase)
            if !normalizedPhrase.isEmpty && normalized.contains(normalizedPhrase) {
                detectedWords.append(phrase)
            }
        }

        // Keep output deterministic and compact.
        let uniqueDetected = Array(Set(detectedWords)).sorted()
        return (contains: !uniqueDetected.isEmpty, detectedWords: uniqueDetected)
    }
    
    // MARK: - Censored Version
    /// Returns a censored version of the content with bad words replaced
    /// - Parameter content: The text to censor
    /// - Returns: Censored text
    static func censorContent(_ content: String) -> String {
        var censoredContent = content

        let allTerms = blockedWords.union(blockedPhrases)
        for term in allTerms {
            let escaped = NSRegularExpression.escapedPattern(for: term)
            let pattern = "\\b\(escaped)\\b"
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(censoredContent.startIndex..., in: censoredContent)

            if let matches = regex?.matches(in: censoredContent, range: range) {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: censoredContent) {
                        let replacement = String(repeating: "*", count: term.count)
                        censoredContent.replaceSubrange(range, with: replacement)
                    }
                }
            }
        }
        
        return censoredContent
    }
    
    // MARK: - Validation Message
    /// Returns a user-friendly message about detected inappropriate content
    /// - Parameter detectedWords: Array of detected inappropriate words
    /// - Returns: Alert message string
    static func getValidationMessage(for detectedWords: [String]) -> String {
        if detectedWords.isEmpty {
            return "Content is appropriate."
        } else if detectedWords.count == 1 {
            return "Your post contains inappropriate language. Please remove offensive words and try again."
        } else {
            return "Your post contains \(detectedWords.count) inappropriate words. Please review and edit your message."
        }
    }

    // MARK: - Normalization
    private static func normalizeForMatching(_ input: String) -> String {
        let lowered = input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        var normalizedChars: [Character] = []
        var previous: Character?

        for ch in lowered {
            let mapped = leetMap[ch] ?? ch
            let isLetterOrNumber = mapped.isLetter || mapped.isNumber
            let normalizedChar: Character = isLetterOrNumber ? mapped : " "

            // Compress repeated letters to reduce "fuuuuuck" and similar obfuscation.
            if normalizedChar == previous, normalizedChar != " " {
                continue
            }

            normalizedChars.append(normalizedChar)
            previous = normalizedChar
        }

        let compacted = String(normalizedChars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return compacted
    }
}
