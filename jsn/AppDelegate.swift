//
//  AppDelegate.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Cocoa

@main
class AppDelegate: NSObject
{
    private var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var checkItem: NSMenuItem? = nil
    private lazy var sprintReviewer =
    {
        SprintReviewer { self.updateMenuItemTitleAndState(forFetchingState: $0) }
    }()
    
    private lazy var settingsWindowController: NSWindowController =
    {
        let window = NSWindow()
        return NSWindowController(window: window)
    }()

    private var viewController: ViewController?
    {
        /// Yeah this line hurst my eyes too, please educate me on how
        /// to do this properly - Jorrit
        return mainWindow?.contentViewController as? ViewController
    }
    
    private var mainWindow: NSWindow?
    {
        /// Watch out, retinal damage might occur
        /// by looking at this implementation!
        for aWindow in NSApplication.shared.windows
        {
            guard let classType = NSClassFromString("NSStatusBarWindow")
            else { fatalError() }
            if !aWindow.isKind(of: classType.self)
            {
                return aWindow
            }
        }
        return nil
    }
    
    @objc private func showSettingsWindow(sender: Any)
    {
        settingsWindowController.window?.level = .floating
        settingsWindowController.window?.title = NSLocalizedString("Jira Sprint Reporter Settings",
                                                                   comment: "")
//        let settingsViewHostingController = SettingsViewHostingController(rootView: SettingsView())
//        settingsWindowController.window?.contentViewController = settingsViewHostingController
        
//        guard let screenSize = NSScreen.main?.visibleFrame.size
//        else { fatalError("No monitor connected? Not covering this case.") }
//
//        let contentSize = settingsViewHostingController.sizeThatFits(in: screenSize)
//        settingsWindowController.window?.setContentSize(contentSize)
//        settingsWindowController.window?.styleMask = [.closable,
//                                                      .miniaturizable,
//                                                      .resizable,
//                                                      .titled]
//        settingsWindowController.showWindow(self)
    }
    
    
    @objc private func showWindow(sender: Any)
    {
        mainWindow?.makeKey()
        mainWindow?.windowController?.showWindow(self)
        mainWindow?.level = .floating
    }
    var defaultImage: NSImage
    {
        guard let defaultImage = NSImage(systemSymbolName: "circle",
                                                accessibilityDescription: nil)
        else { fatalError("Could not create symbol") }
        return defaultImage
    }
    var activityIndicatorImage: NSImage
    {
        guard let defaultImage = NSImage(systemSymbolName: "arrow.clockwise.circle",
                                                accessibilityDescription: nil)
        else { fatalError("Could not create symbol") }
        return defaultImage
    }
    
    private func updateMenuItemTitleAndState(forFetchingState isFetching: Bool)
    {
        checkItem?.isEnabled = !isFetching
        if isFetching
        {
            self.checkItem?.title = NSLocalizedString("Currently Checking...", comment: "")
//            statusBarItem.button?.title = "꩜"
            statusBarItem.button?.image = activityIndicatorImage
        }
        else
        {
            self.checkItem?.title = NSLocalizedString("Check now", comment: "")
//            statusBarItem.button?.title = "◎"
            statusBarItem.button?.image = defaultImage
        }
    }
}

extension AppDelegate: NSApplicationDelegate
{
    func applicationWillFinishLaunching(_ notification: Notification)
    {
        // The application does not appear in the Dock and does not have a menu
        // bar, but it may be activated programmatically or by clicking on one
        // of its windows.
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        let _ = sprintReviewer
        mainWindow?.close()
        mainWindow?.title = "Jira Sprint Notifier"
        
        statusBarItem.button?.title = "◎"
        let statusBarMenu = NSMenu(title: NSLocalizedString("Jira Sprint Updates", comment: ""))
        statusBarItem.menu = statusBarMenu
        statusBarMenu.autoenablesItems = false
        
        let checkItem = NSMenuItem(title: "",
                                  action: #selector(SprintReviewer.obtainSprintReviews(sender:)),
                                  keyEquivalent: "c")
        checkItem.target = sprintReviewer
        statusBarMenu.addItem(checkItem)
        self.checkItem = checkItem
        
        let showWindowItem = NSMenuItem(title: NSLocalizedString("Show Sprint Updates", comment: ""),
                                  action: #selector(AppDelegate.showWindow(sender:)),
                                  keyEquivalent: "s")
        statusBarMenu.addItem(showWindowItem)
        
        let generateSprintRapportsItem =
        NSMenuItem(title: NSLocalizedString("Generate Sprint Reports", comment: ""),
                   action: #selector(AppDelegate.generateSprintReports(sender:)),
                   keyEquivalent: "g")
        statusBarMenu.addItem(generateSprintRapportsItem)
        
        let settingsItem =
        NSMenuItem(title: NSLocalizedString("Settings", comment: ""),
                   action: #selector(AppDelegate.showSettingsWindow(sender:)),
                   keyEquivalent: ",")
        statusBarMenu.addItem(settingsItem)
        
        statusBarMenu.addItem(
            withTitle: NSLocalizedString("Quit", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        
        updateMenuItemTitleAndState(forFetchingState: false)
    }
    
    /// This application can exist without any windows, as it has a menuBarItem
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    { false }
}


extension AppDelegate
{
    @objc private func generateSprintReports(sender: Any)
    {
//        for anIdentifier in userprojectKeys
//        {
//            /// do here what `jsr` command line tool does
//        }
    }
}
