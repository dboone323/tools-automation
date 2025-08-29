//
// HighScoreManager.swift
// AvoidObstaclesGame
//
// Manages high scores with persistent storage using UserDefaults
//

import Foundation

class HighScoreManager {
    static let shared = HighScoreManager()
    private let highScoresKey = "AvoidObstaclesHighScores"
    private let maxScores = 10
    
    private init() {}
    
    // Get all high scores sorted from highest to lowest
    func getHighScores() -> [Int] {
        let scores = UserDefaults.standard.array(forKey: highScoresKey) as? [Int] ?? []
        return scores.sorted(by: >)
    }
    
    // Add a new score and return if it's a new high score
    func addScore(_ score: Int) -> Bool {
        var scores = getHighScores()
        scores.append(score)
        scores.sort(by: >)
        
        // Keep only top 10 scores
        if scores.count > maxScores {
            scores = Array(scores.prefix(maxScores))
        }
        
        UserDefaults.standard.set(scores, forKey: highScoresKey)
        UserDefaults.standard.synchronize()
        
        // Return true if this score is in the top 10
        return scores.contains(score)
    }
    
    // Get the highest score
    func getHighestScore() -> Int {
        return getHighScores().first ?? 0
    }
    
    // Check if a score would be a high score without adding it
    func isHighScore(_ score: Int) -> Bool {
        let scores = getHighScores()
        return scores.count < maxScores || score > (scores.last ?? 0)
    }
    
    // Clear all high scores (for testing or reset functionality)
    func clearHighScores() {
        UserDefaults.standard.removeObject(forKey: highScoresKey)
        UserDefaults.standard.synchronize()
    }
}
