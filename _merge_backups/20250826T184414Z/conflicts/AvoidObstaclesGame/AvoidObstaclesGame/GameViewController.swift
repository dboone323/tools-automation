//
// GameViewController.swift
// AvoidObstaclesGame
//
// Standard ViewController to load and present the GameScene.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the view.
        if let view = self.view as! SKView? {
            // Create and configure the scene.
            // The size is set to the view's bounds, so it fills the screen.
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill // Or .resizeFill, or .fill depending on preference
            
            // Present the scene.
            view.presentScene(scene)
            
            // Optional: For performance tuning
            view.ignoresSiblingOrder = true
            
            // Optional: To see physics bodies and frame rate (uncomment to use)
            // view.showsPhysics = true
            // view.showsFPS = true
            // view.showsNodeCount = true
        }
    }

    // Standard iOS view controller overrides for orientation and status bar.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true // Hides the status bar for a more immersive game experience
    }
}
