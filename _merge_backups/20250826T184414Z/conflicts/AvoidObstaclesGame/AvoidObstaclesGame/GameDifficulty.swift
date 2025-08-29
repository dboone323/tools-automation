//
// GameDifficulty.swift
// AvoidObstaclesGame
//
// Manages game difficulty progression based on score
//

import Foundation

struct GameDifficulty {
    let spawnInterval: Double      // Time between obstacle spawns
    let obstacleSpeed: Double      // Speed of falling obstacles
    let scoreMultiplier: Double    // Score multiplier for this difficulty
    
    static func getDifficulty(for score: Int) -> GameDifficulty {
        switch score {
        case 0..<10:
            return GameDifficulty(spawnInterval: 1.2, obstacleSpeed: 3.5, scoreMultiplier: 1.0)
        case 10..<25:
            return GameDifficulty(spawnInterval: 1.0, obstacleSpeed: 3.0, scoreMultiplier: 1.2)
        case 25..<50:
            return GameDifficulty(spawnInterval: 0.8, obstacleSpeed: 2.5, scoreMultiplier: 1.5)
        case 50..<100:
            return GameDifficulty(spawnInterval: 0.6, obstacleSpeed: 2.0, scoreMultiplier: 2.0)
        case 100..<200:
            return GameDifficulty(spawnInterval: 0.5, obstacleSpeed: 1.5, scoreMultiplier: 2.5)
        default:
            return GameDifficulty(spawnInterval: 0.4, obstacleSpeed: 1.2, scoreMultiplier: 3.0)
        }
    }
    
    static func getDifficultyLevel(for score: Int) -> Int {
        switch score {
        case 0..<10: return 1
        case 10..<25: return 2
        case 25..<50: return 3
        case 50..<100: return 4
        case 100..<200: return 5
        default: return 6
        }
    }
}
