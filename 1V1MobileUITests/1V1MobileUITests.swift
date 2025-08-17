import XCTest

final class OneVOneMobileUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAppLaunch() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.exists)
    }
    
    func testAuthViewElements() throws {
        // Test that authentication view elements are present
        let emailTextField = app.textFields["Email"]
        let passwordSecureTextField = app.secureTextFields["Password"]
        let signInButton = app.buttons["Sign In"]
        
        XCTAssertTrue(emailTextField.exists)
        XCTAssertTrue(passwordSecureTextField.exists)
        XCTAssertTrue(signInButton.exists)
    }
    
    func testSignUpToggle() throws {
        // Test switching between sign in and sign up
        let signUpToggleButton = app.buttons["Don't have an account? Sign Up"]
        XCTAssertTrue(signUpToggleButton.exists)
        
        signUpToggleButton.tap()
        
        // Check that confirm password field appears
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        XCTAssertTrue(confirmPasswordField.exists)
        
        // Check that button text changes
        let signUpButton = app.buttons["Sign Up"]
        XCTAssertTrue(signUpButton.exists)
    }
    
    func testForgotPasswordButton() throws {
        // Test forgot password functionality
        let forgotPasswordButton = app.buttons["Forgot Password?"]
        XCTAssertTrue(forgotPasswordButton.exists)
        
        forgotPasswordButton.tap()
        
        // Add assertions for forgot password flow
        // This would depend on the actual implementation
    }
    
    func testFormValidation() throws {
        // Test form validation
        let signInButton = app.buttons["Sign In"]
        
        // Try to sign in without entering credentials
        signInButton.tap()
        
        // The button should remain enabled but validation should occur
        // Add specific validation checks based on your implementation
    }
    
    func testTabNavigation() throws {
        // This test would require authentication first
        // For now, we'll just test that the app structure is correct
        
        // If user is authenticated, test tab navigation
        if app.tabBars.count > 0 {
            let tabBar = app.tabBars.firstMatch
            
            // Test Home tab
            let homeTab = tabBar.buttons["Home"]
            if homeTab.exists {
                homeTab.tap()
                XCTAssertTrue(homeTab.isSelected)
            }
            
            // Test Profile tab
            let profileTab = tabBar.buttons["Profile"]
            if profileTab.exists {
                profileTab.tap()
                XCTAssertTrue(profileTab.isSelected)
            }
        }
    }
    
    func testAccessibility() throws {
        // Test accessibility features
        let emailTextField = app.textFields["Email"]
        XCTAssertTrue(emailTextField.isAccessibilityElement)
        
        let passwordSecureTextField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordSecureTextField.isAccessibilityElement)
    }
    
    func testPerformance() throws {
        // Test app performance
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // Simulate user interactions
            let emailTextField = app.textFields["Email"]
            emailTextField.tap()
            emailTextField.typeText("test@example.com")
            
            let passwordSecureTextField = app.secureTextFields["Password"]
            passwordSecureTextField.tap()
            passwordSecureTextField.typeText("password123")
        }
    }
}
