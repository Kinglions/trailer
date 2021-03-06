
import UIKit

var app: iOS_AppDelegate!

final class iOS_AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	private var lastUpdateFailed = false
	private var backgroundTask = UIBackgroundTaskInvalid
	private var watchManager: WatchManager?
	private var refreshTimer: NSTimer?
	private var backgroundCallback: ((UIBackgroundFetchResult) -> Void)?
	private var actOnLocalNotification = true

	private var justPostedNotificationTimer: PopTimer!
	private var justPostedNotifications = false

	func updateBadge() {
		UIApplication.sharedApplication().applicationIconBadgeNumber = PullRequest.badgeCountInMoc(mainObjectContext) + Issue.badgeCountInMoc(mainObjectContext)
		watchManager?.updateContext()
	}

	func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		app = self
		justPostedNotificationTimer = PopTimer(timeInterval: 2) { [weak self] in
			self?.justPostedNotifications = false
		}
		return true
	}

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {

		DataManager.postProcessAllItems()

		if ApiServer.someServersHaveAuthTokensInMoc(mainObjectContext) {
			api.updateLimitsFromServer()
		}

		UITabBar.appearance().tintColor = GLOBAL_TINT
		UIBarButtonItem.appearance().tintColor = GLOBAL_TINT

		let splitViewController = window!.rootViewController as! UISplitViewController
		splitViewController.minimumPrimaryColumnWidth = 320
		splitViewController.maximumPrimaryColumnWidth = 320
		splitViewController.delegate = popupManager

		application.setMinimumBackgroundFetchInterval(NSTimeInterval(Settings.backgroundRefreshPeriod))

		atNextEvent(self) { S in
			if DataManager.appIsConfigured {
				if let localNotification = launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
					NotificationManager.handleLocalNotification(localNotification, action: nil)
				}
			} else {

				if !ApiServer.someServersHaveAuthTokensInMoc(mainObjectContext) {
					let m = popupManager.getMasterController()
					if ApiServer.countApiServersInMoc(mainObjectContext) == 1, let a = ApiServer.allApiServersInMoc(mainObjectContext).first where a.authToken == nil || a.authToken!.isEmpty {
						m.performSegueWithIdentifier("showQuickstart", sender: self)
					} else {
						m.performSegueWithIdentifier("showPreferences", sender: self)
					}
				}
			}

			S.watchManager = WatchManager()
		}

		let readAction = UIMutableUserNotificationAction()
		readAction.identifier = "read"
		readAction.title = "Mark as read"
		readAction.destructive = false
		readAction.authenticationRequired = false
		readAction.activationMode = .Background

		let readShort = UIMutableUserNotificationAction()
		readShort.identifier = "read"
		readShort.title = "Read"
		readShort.destructive = false
		readShort.authenticationRequired = false
		readShort.activationMode = .Background

		let muteAction = UIMutableUserNotificationAction()
		muteAction.identifier = "mute"
		muteAction.title = "Mute this item"
		muteAction.destructive = true
		muteAction.authenticationRequired = false
		muteAction.activationMode = .Background

		let muteShort = UIMutableUserNotificationAction()
		muteShort.identifier = "mute"
		muteShort.title = "Mute"
		muteShort.destructive = true
		muteShort.authenticationRequired = false
		muteShort.activationMode = .Background

		let itemCategory = UIMutableUserNotificationCategory()
		itemCategory.identifier = "mutable"
		itemCategory.setActions([readAction, muteAction], forContext: .Default)
		itemCategory.setActions([readShort, muteShort], forContext: .Minimal)

		let repoCategory = UIMutableUserNotificationCategory()
		repoCategory.identifier = "repo"

		let notificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: [itemCategory, repoCategory])
		application.registerUserNotificationSettings(notificationSettings)

		return true
	}

	func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {

		switch shortcutItem.type {

		case "search-items":
			let m = popupManager.getMasterController()
			m.focusFilter()
			completionHandler(true)

		case "mark-all-read":
			markEverythingRead()
			completionHandler(true)

		default:
			completionHandler(false)
		}
	}

	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		if let c = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) {
			if let scheme = c.scheme {
				if scheme == "pockettrailer" {
					return true
				} else {
					settingsManager.loadSettingsFrom(url, confirmFromView: nil, withCompletion: nil)
				}
			}
		}
		return false
	}

	func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
		return NotificationManager.handleUserActivity(userActivity)
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
		if !justPostedNotifications && actOnLocalNotification {
			NotificationManager.handleLocalNotification(notification, action: nil)
		}
	}

	func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
		dispatch_async(dispatch_get_main_queue()) {
			NotificationManager.handleLocalNotification(notification, action: identifier)
			completionHandler()
		}
	}

	func startRefreshIfItIsDue() {

		refreshTimer?.invalidate()
		refreshTimer = nil

		if let l = Settings.lastSuccessfulRefresh {
			let howLongAgo = NSDate().timeIntervalSinceDate(l)
			if fabs(howLongAgo) > NSTimeInterval(Settings.refreshPeriod) {
				startRefresh()
			} else {
				let howLongUntilNextSync = NSTimeInterval(Settings.refreshPeriod) - howLongAgo
				DLog("No need to refresh yet, will refresh in %f", howLongUntilNextSync)
				refreshTimer = NSTimer.scheduledTimerWithTimeInterval(howLongUntilNextSync, target: self, selector: #selector(iOS_AppDelegate.refreshTimerDone), userInfo: nil, repeats: false)
			}
		} else {
			startRefresh()
		}
	}

	func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		backgroundCallback = completionHandler
		startRefresh()
	}

	private func checkApiUsage() {
		for apiServer in ApiServer.allApiServersInMoc(mainObjectContext) {
			if apiServer.goodToGo && apiServer.hasApiLimit, let resetDate = apiServer.resetDate {
				if apiServer.shouldReportOverTheApiLimit {
					let apiLabel = S(apiServer.label)
					let resetDateString = itemDateFormatter.stringFromDate(resetDate)

					showMessage("\(apiLabel) API request usage is over the limit!",
						"Your request cannot be completed until GitHub resets your hourly API allowance at \(resetDateString).\n\nIf you get this error often, try to make fewer manual refreshes or reducing the number of repos you are monitoring.\n\nYou can check your API usage at any time from the bottom of the preferences pane at any time.")
				} else if apiServer.shouldReportCloseToApiLimit {
					let apiLabel = S(apiServer.label)
					let resetDateString = itemDateFormatter.stringFromDate(resetDate)

					showMessage("\(apiLabel) API request usage is close to full",
						"Try to make fewer manual refreshes, increasing the automatic refresh time, or reducing the number of repos you are monitoring.\n\nYour allowance will be reset by GitHub on \(resetDateString).\n\nYou can check your API usage from the bottom of the preferences pane.")
				}
			}
		}
	}

	private func prepareForRefresh() {
		refreshTimer?.invalidate()
		refreshTimer = nil

		appIsRefreshing = true

		backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithName("com.housetrip.Trailer.refresh") { [weak self] in
			self?.endBGTask()
		}

		NSNotificationCenter.defaultCenter().postNotificationName(REFRESH_STARTED_NOTIFICATION, object: nil)
		DLog("Starting refresh")

		api.expireOldImageCacheEntries()
		DataManager.postMigrationTasks()
	}

	func startRefresh() -> Bool {

		if appIsRefreshing || api.noNetworkConnection() || !ApiServer.someServersHaveAuthTokensInMoc(mainObjectContext) {
			return false
		}

		prepareForRefresh()

		api.syncItemsForActiveReposAndCallback({

			popupManager.getMasterController().title = "Processing..."

		}) { [weak self] in

			guard let s = self else { return }

			let success = !ApiServer.shouldReportRefreshFailureInMoc(mainObjectContext)

			s.lastUpdateFailed = !success

			if success {
				Settings.lastSuccessfulRefresh = NSDate()
				preferencesDirty = false
			}

			s.checkApiUsage()
			appIsRefreshing = false
			NSNotificationCenter.defaultCenter().postNotificationName(REFRESH_ENDED_NOTIFICATION, object: nil)
			DataManager.saveDB() // Ensure object IDs are permanent before sending notifications
			DataManager.sendNotificationsIndexAndSave()

			if !success && UIApplication.sharedApplication().applicationState == .Active {
				showMessage("Refresh failed", "Loading the latest data from GitHub failed")
			}

			s.refreshTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(Settings.refreshPeriod), target: s, selector: #selector(iOS_AppDelegate.refreshTimerDone), userInfo: nil, repeats:false)
			DLog("Refresh done")

			s.updateBadge()
			s.endBGTask()

			if let bc = s.backgroundCallback {
				if success && mainObjectContext.hasChanges {
					DLog("Background fetch: Got new data")
					bc(UIBackgroundFetchResult.NewData)
				} else if success {
					DLog("Background fetch: No new data")
					bc(UIBackgroundFetchResult.NoData)
				} else {
					DLog("Background fetch: FAILED")
					bc(UIBackgroundFetchResult.Failed)
				}
				s.backgroundCallback = nil
			}
		}

		return true
	}

	private func endBGTask() {
		if backgroundTask != UIBackgroundTaskInvalid {
			UIApplication.sharedApplication().endBackgroundTask(backgroundTask)
			backgroundTask = UIBackgroundTaskInvalid
		}
	}

	func refreshTimerDone() {
		if DataManager.appIsConfigured {
			startRefresh()
		}
	}

	func applicationDidBecomeActive(application: UIApplication) {
		startRefreshIfItIsDue()
		actOnLocalNotification = false
	}

	func applicationWillEnterForeground(application: UIApplication) {
		actOnLocalNotification = true
	}

	func applicationDidEnterBackground(application: UIApplication) {
		actOnLocalNotification = false
	}

	func applicationWillResignActive(application: UIApplication) {
		actOnLocalNotification = true
	}

	func postNotificationOfType(type: NotificationType, forItem: DataItem) {
		justPostedNotifications = true
		NotificationManager.postNotificationOfType(type, forItem: forItem)
		if UIApplication.sharedApplication().applicationState == .Background {
			justPostedNotifications = false
		} else {
			justPostedNotificationTimer.push()
		}
	}

	func markEverythingRead() {
		PullRequest.markEverythingRead(.None, moc: mainObjectContext)
		Issue.markEverythingRead(.None, moc: mainObjectContext)
		DataManager.saveDB()
		app.updateBadge()
	}

	func clearAllClosed() {
		for p in PullRequest.allClosedInMoc(mainObjectContext, includeAllGroups: true) {
			mainObjectContext.deleteObject(p)
		}
		for i in Issue.allClosedInMoc(mainObjectContext, includeAllGroups: true) {
			mainObjectContext.deleteObject(i)
		}
		DataManager.saveDB()
		popupManager.getMasterController().updateStatus()
	}

	func clearAllMerged() {
		for p in PullRequest.allMergedInMoc(mainObjectContext, includeAllGroups: true) {
			mainObjectContext.deleteObject(p)
		}
		DataManager.saveDB()
		popupManager.getMasterController().updateStatus()
	}
}
