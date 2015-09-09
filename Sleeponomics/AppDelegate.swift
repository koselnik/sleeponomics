//
//  AppDelegate.swift
//  Sleeponomics
//
//  Created by Christofer Roth on 31/08/15.
//  Copyright (c) 2015 Prototyp. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UIAlertViewDelegate, PHBridgeSelectionViewControllerDelegate, PHBridgePushLinkViewControllerDelegate {

    var window: UIWindow?
    var phHueSDK: PHHueSDK?

    var bridgeSearch: PHBridgeSearching?

    var noConnectionAlert: UIAlertView?
    var noBridgeFoundAlert: UIAlertView?
    var authenticationFailedAlert: UIAlertView?
    
    var loadingView: PHLoadingViewController?
    var pushLinkViewController: PHBridgePushLinkViewController?
    var bridgeSelectionViewController: PHBridgeSelectionViewController?
    var navigationController: UINavigationController?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        phHueSDK = PHHueSDK()
        phHueSDK!.startUpSDK()
        phHueSDK!.enableLogging(true)

        let storyboard = UIStoryboard(name: "Main", bundle:nil)
        let settingsViewController = storyboard.instantiateViewControllerWithIdentifier("settings") as! HomeViewController

        navigationController = UINavigationController(rootViewController: settingsViewController)

        window!.rootViewController = self.navigationController
        window!.makeKeyAndVisible()
        
        let notificationManager = PHNotificationManager()

        notificationManager.registerObject(self, withSelector: Selector("localConnection"), forNotification: LOCAL_CONNECTION_NOTIFICATION)
        notificationManager.registerObject(self, withSelector: Selector("noLocalConnection"), forNotification: NO_LOCAL_CONNECTION_NOTIFICATION)
        notificationManager.registerObject(self, withSelector: Selector("notAuthenticated"), forNotification: NO_LOCAL_AUTHENTICATION_NOTIFICATION)

        enableLocalHeartbeat()

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Stop heartbeat
        disableLocalHeartbeat()
        
        // Remove any open popups
        if noConnectionAlert != nil {
            noConnectionAlert!.dismissWithClickedButtonIndex(noConnectionAlert!.cancelButtonIndex, animated: false)
            noConnectionAlert = nil
        }
        if noBridgeFoundAlert != nil {
            noBridgeFoundAlert!.dismissWithClickedButtonIndex(noBridgeFoundAlert!.cancelButtonIndex, animated: false)
            noBridgeFoundAlert = nil
        }
        if authenticationFailedAlert != nil {
            authenticationFailedAlert!.dismissWithClickedButtonIndex(authenticationFailedAlert!.cancelButtonIndex, animated: false)
            authenticationFailedAlert = nil
        }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state here you can undo many of the changes made on entering the background.
        enableLocalHeartbeat()
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    //#pragma mark - HueSDK

    /**
     Notification receiver for successful local connection
     */
    func localConnection() {
        // Check current connection state
        checkConnectionState()
    }

    /**
     Notification receiver for failed local connection
     */
    func noLocalConnection() {
        // Check current connection state
        checkConnectionState()
    }

    /**
     Notification receiver for failed local authentication
     */
    func notAuthenticated() {
        // Move to main screen (as you can't control lights when not connected)
        navigationController!.popToRootViewControllerAnimated(true)

        // Dismiss modal views when connection is lost
        if navigationController!.presentedViewController != nil {
            navigationController!.dismissViewControllerAnimated(true, completion:nil)
        }
        
        // Remove no connection alert
        if noConnectionAlert != nil {
            noConnectionAlert!.dismissWithClickedButtonIndex(noConnectionAlert!.cancelButtonIndex, animated:true)
            noConnectionAlert = nil
        }

        // Start local authenticion process
        NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("doAuthentication"), userInfo: nil, repeats: false)
    }

    /**
     Checks if we are currently connected to the bridge locally and if not, it will show an error when the error is not already shown.
     */
    func checkConnectionState() {
        if !phHueSDK!.localConnected() {
            // Dismiss modal views when connection is lost
            if navigationController!.presentedViewController != nil {
                navigationController!.dismissViewControllerAnimated(true, completion:nil)
            }

            // No connection at all, show connection popup
            if noConnectionAlert == nil {
                navigationController!.popToRootViewControllerAnimated(true)

                // Showing popup, so remove this view
                removeLoadingView()
                showNoConnectionDialog()
            }
        }
        else {
            // One of the connections is made, remove popups and loading views
            if noConnectionAlert != nil {
                noConnectionAlert!.dismissWithClickedButtonIndex(noConnectionAlert!.cancelButtonIndex, animated:true)
                noConnectionAlert = nil
            }
            removeLoadingView()
            
        }
    }

    /**
     Shows the first no connection alert with more connection options
     */
    func showNoConnectionDialog() {
        noConnectionAlert = UIAlertView(title: "No connection", message: "Connection to bridge lost", delegate: self, cancelButtonTitle: nil, otherButtonTitles: "Reconnect", "Cancel")
        noConnectionAlert!.tag = 1
        noConnectionAlert!.show()
    }

    //#mark - Heartbeat control
    
    /**
    Starts the local heartbeat with a 10 second interval
    */
    func enableLocalHeartbeat() {
        /***************************************************
        The heartbeat processing collects data from the bridge
        so now try to see if we have a bridge already connected
        *****************************************************/
        let cache = PHBridgeResourcesReader.readBridgeResourcesCache()
        if cache?.bridgeConfiguration?.ipaddress != nil {
            showLoadingViewWithText("Connecting...")
            // Enable heartbeat with interval of 10 seconds
            phHueSDK!.enableLocalConnection()
        } else {
            // Automaticly start searching for bridges
            searchForBridgeLocal()
        }
    }

    func disableLocalHeartbeat() {
        phHueSDK!.disableLocalConnection()
    }

    //#pragma mark - Bridge searching and selection

    /**
     Search for bridges using UPnP and portal discovery, shows results to user or gives error when none found.
     */
    func searchForBridgeLocal() {
        // Stop heartbeats
        disableLocalHeartbeat()
        
        // Show search screen
        showLoadingViewWithText("Searching...")

        /***************************************************
         A bridge search is started using UPnP to find local bridges
         *****************************************************/
        
        // Start search
        bridgeSearch = PHBridgeSearching(upnpSearch: true, andPortalSearch: true, andIpAdressSearch: true)

        bridgeSearch?.startSearchWithCompletionHandler({ (bridgesFound: [NSObject: AnyObject]!) in
            // Done with search, remove loading view
            self.removeLoadingView()

            /***************************************************
             The search is complete, check whether we found a bridge
             *****************************************************/
            
            // Check for results
            if bridgesFound.count > 0 {
                // Results were found, show options to user (from a user point of view, you should select automatically when there is only one bridge found)
                self.bridgeSelectionViewController = PHBridgeSelectionViewController(nibName: "PHBridgeSelectionViewController", bundle:NSBundle.mainBundle(), bridges:bridgesFound, delegate:self)

                /***************************************************
                 Use the list of bridges, present them to the user, so one can be selected.
                 *****************************************************/
                let navController = UINavigationController(rootViewController: self.bridgeSelectionViewController!)
                navController.modalPresentationStyle = UIModalPresentationStyle.FormSheet
                self.navigationController!.presentViewController(navController, animated:true, completion:nil)
            }
            else {
                /***************************************************
                 No bridge was found was found. Tell the user and offer to retry..
                 *****************************************************/
                
                // No bridges were found, show this to the user
                self.noBridgeFoundAlert = UIAlertView(title: "No bridges", message: "Could not find bridge", delegate: self, cancelButtonTitle: nil, otherButtonTitles:"Retry", "Cancel")
                self.noBridgeFoundAlert!.tag = 1
                self.noBridgeFoundAlert!.show()
            }
        })
    }

    /**
     Delegate method for PHbridgeSelectionViewController which is invoked when a bridge is selected
     */
    func bridgeSelectedWithIpAddress(ipAddress: String!, andBridgeId bridgeId: String!) {
        // Remove the selection view controller
        bridgeSelectionViewController = nil
        navigationController!.dismissViewControllerAnimated(true, completion:nil)
        
        // Show a connecting view while we try to connect to the bridge
        showLoadingViewWithText("Connecting...")

        phHueSDK!.setBridgeToUseWithId(bridgeId, ipAddress:ipAddress)
        
        // Start local heartbeat again
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("enableLocalHeartbeat"), userInfo: nil, repeats: false)
    }

    //#pragma mark - Bridge authentication

    /**
     Start the local authentication process
     */
    func doAuthentication() {
        // Disable heartbeats
        disableLocalHeartbeat()

        // Create an interface for the pushlinking
        pushLinkViewController = PHBridgePushLinkViewController(nibName: "PHBridgePushLinkViewController", bundle: NSBundle.mainBundle(), hueSDK: phHueSDK, delegate: self)

        navigationController!.presentViewController(pushLinkViewController!, animated:true, completion: { () in
            self.pushLinkViewController!.startPushLinking()
        })
    }

    /**
     Delegate method for PHBridgePushLinkViewController which is invoked if the pushlinking was successfull
     */
    func pushlinkSuccess() {
        // Remove pushlink view controller
        navigationController!.dismissViewControllerAnimated(true, completion:nil)
        pushLinkViewController = nil
        
        // Start local heartbeat
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("enableLocalHeartbeat"), userInfo: nil, repeats: false)
    }

    /**
     Delegate method for PHBridgePushLinkViewController which is invoked if the pushlinking was not successfull
     */
    func pushlinkFailed(error: PHError) {
        // Remove pushlink view controller
        navigationController!.dismissViewControllerAnimated(true, completion:nil)
        pushLinkViewController = nil

        // Check which error occured
        if error.code == 60 { // PUSHLINK_NO_CONNECTION = 60
            // No local connection to bridge
            noLocalConnection()
            
            // Start local heartbeat (to see when connection comes back)
            NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("enableLocalHeartbeat"), userInfo: nil, repeats: false)
        }
        else {
            // Bridge button not pressed in time
            authenticationFailedAlert = UIAlertView(title: "Authentication failed", message: "Make sure you press the button within 30 seconds", delegate: self, cancelButtonTitle: nil, otherButtonTitles: "Retry", "Cancel")
            authenticationFailedAlert!.show()
        }
    }

    // #pragma mark - Alertview delegate

    func alertView(alertView: UIAlertView, buttonIndex: Int) {
        if alertView == noConnectionAlert && alertView.tag == 1 {
            // This is a no connection alert with option to reconnect or more options
            noConnectionAlert = nil

            if buttonIndex == 0 {
                // Retry, just wait for the heartbeat to finish
                showLoadingViewWithText("Connecting...")
            }
            else if buttonIndex == 1 {
                // Find new bridge button
                searchForBridgeLocal()
            }
            else if buttonIndex == 2 {
                // Cancel and disable local heartbeat unit started manually again
                disableLocalHeartbeat()
            }
        }
        else if alertView == noBridgeFoundAlert && alertView.tag == 1 {
            // This is the alert which is shown when no bridges are found locally
            noBridgeFoundAlert = nil

            if buttonIndex == 0 {
                // Retry
                searchForBridgeLocal()
            } else if buttonIndex == 1 {
                // Cancel and disable local heartbeat unit started manually again
                disableLocalHeartbeat()
            }
        }
        else if alertView == authenticationFailedAlert {
            // This is the alert which is shown when local pushlinking authentication has failed
            authenticationFailedAlert = nil
            
            if buttonIndex == 0 {
                // Retry authentication
                doAuthentication()
            } else if buttonIndex == 1 {
                // Remove connecting loading message
                removeLoadingView()
                // Cancel authentication and disable local heartbeat unit started manually again
                disableLocalHeartbeat()
            }
        }
    }

    // #pragma mark - Loading view

    /**
     Shows an overlay over the whole screen with a black box with spinner and loading text in the middle
     @param text The text to display under the spinner
     */
    func showLoadingViewWithText(text: String) {
        // First remove
        removeLoadingView()

        // Then add new
        loadingView = PHLoadingViewController(nibName: "PHLoadingViewController", bundle: NSBundle.mainBundle())
        loadingView!.view.frame = navigationController!.view.bounds
        navigationController!.view.addSubview(loadingView!.view)
        loadingView!.loadingLabel.text = text
    }

    /**
     Removes the full screen loading overlay.
     */
    func removeLoadingView() {
        if loadingView != nil {
            loadingView!.view.removeFromSuperview()
            loadingView = nil
        }
    }
}

