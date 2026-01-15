// ContentFilter.swift
import Foundation

struct ContentFilter {
    
    // MARK: - Bad Words List
    private static let badWords: Set<String> = [
        // Profanity
        "fuck", "shit", "damn", "hell", "ass", "bitch", "bastard",
        "crap", "piss", "dick", "cock", "pussy", "slut", "whore",
        
        // Offensive/Hateful
        "stupid", "idiot", "dumb", "moron", "retard", "fag", "faggot",
        "nigger", "nigga", "chink", "spic", "kike", "wetback",
        
        // Violence/Threats
        "kill", "murder", "die", "dead", "suicide", "rape",
        
        // Add more words as needed
        // You can expand this list based on your community guidelines
    ]
    
    // MARK: - Filter Method
    /// Checks if content contains inappropriate words
    /// - Parameter content: The text to check
    /// - Returns: Tuple with (containsBadWords, detectedWords)
    static func containsInappropriateContent(_ content: String) -> (contains: Bool, detectedWords: [String]) {
        let normalizedContent = content.lowercased()
        var detectedWords: [String] = []
        
        // Check each word in the content
        let words = normalizedContent.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            // Remove punctuation for better matching
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            if badWords.contains(cleanWord) {
                detectedWords.append(cleanWord)
            }
        }
        
        // Also check for words embedded in longer strings (e.g., "f**king")
        for badWord in badWords {
            if normalizedContent.contains(badWord) && !detectedWords.contains(badWord) {
                detectedWords.append(badWord)
            }
        }
        
        return (contains: !detectedWords.isEmpty, detectedWords: detectedWords)
    }
    
    // MARK: - Censored Version
    /// Returns a censored version of the content with bad words replaced
    /// - Parameter content: The text to censor
    /// - Returns: Censored text
    static func censorContent(_ content: String) -> String {
        var censoredContent = content
        
        for badWord in badWords {
            let pattern = "\\b\(badWord)\\b"
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(censoredContent.startIndex..., in: censoredContent)
            
            if let matches = regex?.matches(in: censoredContent, range: range) {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: censoredContent) {
                        let replacement = String(repeating: "*", count: badWord.count)
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
}
