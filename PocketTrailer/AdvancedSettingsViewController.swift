
import UIKit

final class AdvancedSettingsViewController: UITableViewController, PickerViewControllerDelegate, UIDocumentPickerDelegate, UISearchBarDelegate {

	private enum SettingsSection: Int {
		case Refresh, Display, Filtering, AppleWatch, Comments, Repos, StausesAndLabels, History, Confirm, Sort, Misc
		static let allNames = ["Auto Refresh", "Display", "Filtering", "Apple Watch", "Comments", "Watchlist", "Statuses & Labels", "History", "Don't confirm when", "Sorting", "Misc"]
		func title() -> String { return SettingsSection.allNames[rawValue] }
	}

	private struct Setting {
		let section: SettingsSection
		let title: String
		let description: String
		var valueDisplayed: ()->String?

		func isRelevantTo(s: String?, showingHelp: Bool) -> Bool {
			if let s = s?.trim() where !s.isEmpty {
				return title.localizedCaseInsensitiveContainsString(s) || (showingHelp && description.localizedCaseInsensitiveContainsString(s))
			} else {
				return true
			}
		}
	}

	private let settings = [
		Setting(section: .Refresh,
			title: "Foreground refresh interval",
			description: Settings.refreshPeriodHelp,
			valueDisplayed: { String(format: "%.0f seconds", Settings.refreshPeriod) }),
		Setting(section: .Refresh,
			title: "Background refresh interval (minimum)",
			description: Settings.backgroundRefreshPeriodHelp,
			valueDisplayed: { String(format: "%.0f minutes", Settings.backgroundRefreshPeriod/60.0) }),
		Setting(section: .Refresh,
			title: "Watchlist & team list refresh interval",
			description: Settings.newRepoCheckPeriodHelp,
			valueDisplayed: { String(format: "%.0f hours", Settings.newRepoCheckPeriod) }),

		Setting(section: .Display,
			title: "Display item creation times instead of update times",
			description: Settings.showCreatedInsteadOfUpdatedHelp,
			valueDisplayed: { Settings.showCreatedInsteadOfUpdated ? "✓" : " " }),
		Setting(section: .Display,
			title: "Assigned items",
			description: "How to handle items that have been detected as assigned to you.",
			valueDisplayed: { AssignmentPolicy(rawValue: Settings.assignedPrHandlingPolicy)?.name() }),
		Setting(section: .Display,
			title: "Mark unmergeable PRs only in 'My' or 'Participated' sections",
			description: Settings.markUnmergeableOnUserSectionsOnlyHelp,
			valueDisplayed: { Settings.markUnmergeableOnUserSectionsOnly ? "✓" : " " }),
		Setting(section: .Display,
			title: "Display repository names",
			description: Settings.showReposInNameHelp,
			valueDisplayed: { Settings.showReposInName ? "✓" : " " }),
		Setting(section: .Display,
			title: "Open items directly in Safari if internal web view is not already visible.",
			description: Settings.openItemsDirectlyInSafariHelp,
			valueDisplayed: { Settings.openItemsDirectlyInSafari ? "✓" : " " }),
		Setting(section: .Display,
			title: "Separate API servers into their own groups",
			description: Settings.showSeparateApiServersInMenuHelp,
			valueDisplayed: { Settings.showSeparateApiServersInMenu ? "✓" : " " }),
		Setting(section: .Display,
			title: "Try requesting desktop GitHub pages",
			description: Settings.alwaysRequestDesktopSiteHelp,
			valueDisplayed: { Settings.alwaysRequestDesktopSite ? "✓" : " " }),

		Setting(section: .Filtering,
			title: "Include item titles",
			description: Settings.includeTitlesInFilterHelp,
			valueDisplayed: { Settings.includeTitlesInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include repository names",
			description: Settings.includeReposInFilterHelp,
			valueDisplayed: { Settings.includeReposInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include labels",
			description: Settings.includeLabelsInFilterHelp,
			valueDisplayed: { Settings.includeLabelsInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include statuses",
			description: Settings.includeStatusesInFilterHelp,
			valueDisplayed: { Settings.includeStatusesInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include servers",
			description: Settings.includeServersInFilterHelp,
			valueDisplayed: { Settings.includeServersInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include usernames",
			description: Settings.includeUsersInFilterHelp,
			valueDisplayed: { Settings.includeUsersInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include PR or issue numbers",
			description: Settings.includeNumbersInFilterHelp,
			valueDisplayed: { Settings.includeNumbersInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include milestone titles",
			description: Settings.includeMilestonesInFilterHelp,
			valueDisplayed: { Settings.includeMilestonesInFilter ? "✓" : " " }),
		Setting(section: .Filtering,
			title: "Include assignee names",
			description: Settings.includeAssigneeInFilterHelp,
			valueDisplayed: { Settings.includeAssigneeNamesInFilter ? "✓" : " " }),

		Setting(section: .AppleWatch,
			title: "Prefer issues instead of PRs in Apple Watch glances & complications",
			description: Settings.preferIssuesInWatchHelp,
			valueDisplayed: { Settings.preferIssuesInWatch ? "✓" : " " }),
		Setting(section: .AppleWatch,
			title: "Hide descriptions in Apple Watch detail views",
			description: Settings.hideDescriptionInWatchDetailHelp,
			valueDisplayed: { Settings.hideDescriptionInWatchDetail ? "✓" : " " }),

		Setting(section: .Comments,
			title: "Badge & send alerts for the 'all' section too",
			description: Settings.showCommentsEverywhereHelp,
			valueDisplayed: { Settings.showCommentsEverywhere ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Only display items with unread comments",
			description: Settings.hideUncommentedItemsHelp,
			valueDisplayed: { Settings.hideUncommentedItems ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Move items mentioning me to 'Mentioned'",
			description: Settings.autoMoveOnCommentMentionsHelp,
			valueDisplayed: { Settings.autoMoveOnCommentMentions ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Move items mentioning my teams to 'Mentioned'",
			description: Settings.autoMoveOnTeamMentionsHelp,
			valueDisplayed: { Settings.autoMoveOnTeamMentions ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Move items created in my repos to 'Mentioned'",
			description: Settings.moveNewItemsInOwnReposToMentionedHelp,
			valueDisplayed: { Settings.moveNewItemsInOwnReposToMentioned ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Open items at first unread comment",
			description: Settings.openPrAtFirstUnreadCommentHelp,
			valueDisplayed: { Settings.openPrAtFirstUnreadComment ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Block comment notifications from usernames...",
			description: "A list of usernames whose comments you don't want to receive notifications for.",
			valueDisplayed: { ">" }),
		Setting(section: .Comments,
			title: "Disable all comment notifications",
			description: Settings.disableAllCommentNotificationsHelp,
			valueDisplayed: { Settings.disableAllCommentNotifications ? "✓" : " "  }),
		Setting(section: .Comments,
			title: "Mark any comments before my own as read",
			description: Settings.assumeReadItemIfUserHasNewerCommentsHelp,
			valueDisplayed: { Settings.assumeReadItemIfUserHasNewerComments ? "✓" : " " }),

		Setting(section: .Repos,
			title: "PR visibility for new repos",
			description: Settings.displayPolicyForNewPrsHelp,
			valueDisplayed: { RepoDisplayPolicy(rawValue: Settings.displayPolicyForNewPrs)?.name() }),
		Setting(section: .Repos,
			title: "Issue visibility for new repos",
			description: Settings.displayPolicyForNewIssuesHelp,
			valueDisplayed: { RepoDisplayPolicy(rawValue: Settings.displayPolicyForNewIssues)?.name() }),

		Setting(section: .StausesAndLabels,
			title: "Show statuses",
			description: Settings.showStatusItemsHelp,
			valueDisplayed: { Settings.showStatusItems ? "✓" : " " }),
		Setting(section: .StausesAndLabels,
			title: "Re-query statuses",
			description: Settings.statusItemRefreshIntervalHelp,
			valueDisplayed: { Settings.statusItemRefreshInterval == 1 ? "Every refresh" : "Every \(Settings.statusItemRefreshInterval) refreshes" }),
		Setting(section: .StausesAndLabels,
			title: "Show labels",
			description: Settings.showLabelsHelp,
			valueDisplayed: { Settings.showLabels ? "✓" : " " }),
		Setting(section: .StausesAndLabels,
			title: "Re-query labels",
			description: Settings.labelRefreshIntervalHelp,
			valueDisplayed: { Settings.labelRefreshInterval == 1 ? "Every refresh" : "Every \(Settings.labelRefreshInterval) refreshes" }),
		Setting(section: .StausesAndLabels,
			title: "Notify status changes for my & participated PRs",
			description: Settings.notifyOnStatusUpdatesHelp,
			valueDisplayed: { Settings.notifyOnStatusUpdates ? "✓" : " " }),
		Setting(section: .StausesAndLabels,
			title: "...in the 'All' section too",
			description: Settings.notifyOnStatusUpdatesForAllPrsHelp,
			valueDisplayed: { Settings.notifyOnStatusUpdatesForAllPrs ? "✓" : " " }),
		Setting(section: .StausesAndLabels,
			title: "Hide PRs whose status items are not all green",
			description: Settings.hidePrsThatArentPassingHelp,
			valueDisplayed: { Settings.hidePrsThatArentPassing ? "✓" : " " }),
		Setting(section: .StausesAndLabels,
			title: "...only in the 'All' section",
			description: Settings.hidePrsThatDontPassOnlyInAllHelp,
			valueDisplayed: { Settings.hidePrsThatDontPassOnlyInAll ? "✓" : " " }),

		Setting(section: .History,
			title: "When something is merged",
			description: Settings.mergeHandlingPolicyHelp,
			valueDisplayed: { HandlingPolicy(rawValue: Settings.mergeHandlingPolicy)?.name() }),
		Setting(section: .History,
			title: "When something is closed",
			description: Settings.closeHandlingPolicyHelp,
			valueDisplayed: { HandlingPolicy(rawValue: Settings.closeHandlingPolicy)?.name() }),
		Setting(section: .History,
			title: "Don't keep PRs merged by me",
			description: Settings.dontKeepPrsMergedByMeHelp,
			valueDisplayed: { Settings.dontKeepPrsMergedByMe ? "✓" : " " }),

		Setting(section: .Confirm,
			title: "Removing all merged items",
			description: Settings.dontAskBeforeWipingMergedHelp,
			valueDisplayed: { Settings.dontAskBeforeWipingMerged ? "✓" : " " }),
		Setting(section: .Confirm,
			title: "Removing all closed items",
			description: Settings.dontAskBeforeWipingClosedHelp,
			valueDisplayed: { Settings.dontAskBeforeWipingClosed ? "✓" : " " }),

		Setting(section: .Sort,
			title: "Direction",
			description: Settings.sortDescendingHelp,
			valueDisplayed: { Settings.sortDescending ? "Reverse" : "Normal" }),
		Setting(section: .Sort,
			title: "Criterion",
			description: Settings.sortMethodHelp,
			valueDisplayed: {
				if let m = SortingMethod(rawValue: Settings.sortMethod) {
					return Settings.sortDescending ? m.reverseTitle() : m.normalTitle()
				} else {
					return nil
				}
			}),
		Setting(section: .Sort,
			title: "Group by repository",
			description: Settings.groupByRepoHelp,
			valueDisplayed: { Settings.groupByRepo ? "✓" : " " }),

		Setting(section: .Misc,
			title: "Log activity to console",
			description: Settings.logActivityToConsoleHelp,
			valueDisplayed: { Settings.logActivityToConsole ? "✓" : " " }),
		Setting(section: .Misc,
			title: "Log API calls to console",
			description: Settings.dumpAPIResponsesInConsoleHelp,
			valueDisplayed: { Settings.dumpAPIResponsesInConsole ? "✓" : " " })
	]

	private var settingsChangedTimer: PopTimer!
	private var searchTimer: PopTimer!

	// Search
	@IBOutlet weak var searchBar: UISearchBar!

	// for the picker
	private var valuesToPush: [String]?
	private var pickerName: String?
	private var selectedIndexPath: NSIndexPath?
	private var previousValue: Int?
	private var showHelp = true

	@IBAction func done(sender: UIBarButtonItem) {
		if preferencesDirty { app.startRefresh() }
		dismissViewControllerAnimated(true, completion: nil)
	}

	private func reload() {
		heightCache.removeAll()
		tableView.reloadData()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		searchTimer = PopTimer(timeInterval: 0.2) { [weak self] in
			self?.reload()
		}

		settingsChangedTimer = PopTimer(timeInterval: 1.0) {
			DataManager.postProcessAllItems()
			DataManager.saveDB()
			popupManager.getMasterController().updateStatus()
		}

		navigationItem.rightBarButtonItems = [
			UIBarButtonItem(image: UIImage(named: "export"), style: .Plain, target: self, action: #selector(AdvancedSettingsViewController.exportSelected(_:))),
			UIBarButtonItem(image: UIImage(named: "import"), style: .Plain, target: self, action: #selector(AdvancedSettingsViewController.importSelected(_:))),
			UIBarButtonItem(image: UIImage(named: "showHelp"), style: .Plain, target: self, action: #selector(AdvancedSettingsViewController.toggleHelp(_:))),
		]
	}

	override func scrollViewDidScroll(scrollView: UIScrollView) {
		view.endEditing(false)
	}

	func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
		searchTimer.push()
	}

	func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
		searchBar.setShowsCancelButton(true, animated: true)
	}

	func searchBarTextDidEndEditing(searchBar: UISearchBar) {
		searchBar.setShowsCancelButton(false, animated: true)
	}
	
	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		searchBar.text = nil
		searchTimer.push()
		view.endEditing(false)
	}

	func searchBar(searchBar: UISearchBar, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
		if text == "\n" {
			view.endEditing(false)
			return false
		} else {
			return true
		}
	}

	func toggleHelp(button: UIBarButtonItem) {
		showHelp = !showHelp
		if let s = searchBar.text where !s.isEmpty {
			reload()
		} else {
			heightCache.removeAll()
			tableView.reloadSections(NSIndexSet(indexesInRange: NSMakeRange(0, tableView.numberOfSections)), withRowAnimation: .Automatic)
		}
	}

	private func filteringSectionFooter() -> UILabel {
		let p = NSMutableParagraphStyle()
		p.headIndent = 15.0
		p.firstLineHeadIndent = 15.0
		p.tailIndent = -15.0

		let l = UILabel()
		l.attributedText = NSAttributedString(
			string: "You can also use title: server: label: repo: user: number: milestone: assignee: and status: to filter specific properties, e.g. \"label:bug,suggestion\". Prefix with '!' to exclude some terms.",
			attributes: [
				NSFontAttributeName: UIFont.systemFontOfSize(UIFont.smallSystemFontSize()),
				NSForegroundColorAttributeName: UIColor.lightGrayColor(),
				NSParagraphStyleAttributeName: p,
			])
		l.numberOfLines = 0
		return l
	}

	override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		let isFilterFooter = filteredSections()[section].title() == SettingsSection.Filtering.title()
		if isFilterFooter {
			return filteringSectionFooter()
		}
		return nil
	}

	override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 55
	}

	override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		let isFilterFooter = filteredSections()[section].title() == SettingsSection.Filtering.title()
		if isFilterFooter {
			return filteringSectionFooter().sizeThatFits(CGSizeMake(tableView.bounds.size.width, 500.0)).height + 15.0
		}
		return 0
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell") as! AdvancedSettingsCell
		configureCell(cell, indexPath: indexPath)
		return cell
	}

	private func configureCell(cell: AdvancedSettingsCell, indexPath: NSIndexPath) {

		let settingsForSection = filteredItemsForTableSection(indexPath.section)
		let setting = settingsForSection[indexPath.row]
		cell.titleLabel.text = setting.title
		cell.descriptionLabel.text = setting.description

		let v = setting.valueDisplayed()
		if v == "✓" {
			cell.accessoryType = .Checkmark
			cell.valueLabel.text = " "
		} else if v == ">" {
			cell.accessoryType = .DisclosureIndicator
			cell.valueLabel.text = " "
		} else {
			cell.accessoryType = .None
			cell.valueLabel.text = v ?? " "
		}

		cell.detailsBottomAnchor.priority = 750
		if showHelp {
			cell.detailsBottomAnchor.constant = 6
			cell.detailsTopAnchor.constant = 6
		} else {
			cell.descriptionLabel.text = nil
			cell.detailsBottomAnchor.constant = 4
			cell.detailsTopAnchor.constant = 0
		}
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

		let setting = filteredItemsForTableSection(indexPath.section)[indexPath.row]
		let section = filteredSections()[indexPath.section]
		let unFilteredItemsForSection = settings.filter { $0.section == section }

		var originalIndex = 0
		for x in unFilteredItemsForSection {
			if x.title == setting.title {
				break
			}
			originalIndex += 1
		}

		previousValue = nil

		if section == SettingsSection.Refresh {
			pickerName = setting.title
			selectedIndexPath = indexPath
			var values = [String]()
			var count=0
			switch originalIndex {
			case 0:
				// seconds
				for f in 60.stride(to: 3600, by: 10) {
					if f == Int(Settings.refreshPeriod) { previousValue = count }
					values.append("\(f) seconds")
					count += 1
				}
			case 1:
				// minutes
				for f in 5.stride(to: 10000, by: 5) {
					if f == Int(Settings.backgroundRefreshPeriod/60.0) { previousValue = count }
					values.append("\(f) minutes")
					count += 1
				}
			case 2:
				// hours
				for f in 2..<100 {
					if f == Int(Settings.newRepoCheckPeriod) { previousValue = count }
					values.append("\(f) hours")
					count += 1
				}
			default: break
			}
			valuesToPush = values
			performSegueWithIdentifier("showPicker", sender: self)

		} else if section == SettingsSection.Display {
			switch originalIndex {
			case 0:
				Settings.showCreatedInsteadOfUpdated = !Settings.showCreatedInsteadOfUpdated
				settingsChangedTimer.push()
			case 1:
				pickerName = setting.title
				selectedIndexPath = indexPath
				valuesToPush = AssignmentPolicy.labels
				previousValue = Settings.assignedPrHandlingPolicy
				performSegueWithIdentifier("showPicker", sender: self)
			case 2:
				Settings.markUnmergeableOnUserSectionsOnly = !Settings.markUnmergeableOnUserSectionsOnly
				settingsChangedTimer.push()
			case 3:
				Settings.showReposInName = !Settings.showReposInName
				settingsChangedTimer.push()
			case 4:
				Settings.openItemsDirectlyInSafari = !Settings.openItemsDirectlyInSafari
			case 5:
				Settings.showSeparateApiServersInMenu = !Settings.showSeparateApiServersInMenu
				settingsChangedTimer.push()
			case 6:
				Settings.alwaysRequestDesktopSite = !Settings.alwaysRequestDesktopSite
			default: break
			}
		} else if section == SettingsSection.Filtering {
			switch originalIndex {
			case 0:
				Settings.includeTitlesInFilter = !Settings.includeTitlesInFilter
			case 1:
				Settings.includeReposInFilter = !Settings.includeReposInFilter
			case 2:
				Settings.includeLabelsInFilter = !Settings.includeLabelsInFilter
			case 3:
				Settings.includeStatusesInFilter = !Settings.includeStatusesInFilter
			case 4:
				Settings.includeServersInFilter = !Settings.includeServersInFilter
			case 5:
				Settings.includeUsersInFilter = !Settings.includeUsersInFilter
			case 6:
				Settings.includeNumbersInFilter = !Settings.includeNumbersInFilter
			case 7:
				Settings.includeMilestonesInFilter = !Settings.includeMilestonesInFilter
			case 8:
				Settings.includeAssigneeNamesInFilter = !Settings.includeAssigneeNamesInFilter
			default: break
			}
			settingsChangedTimer.push()
		} else if section == SettingsSection.AppleWatch {
			switch originalIndex {
			case 0:
				Settings.preferIssuesInWatch = !Settings.preferIssuesInWatch
				settingsChangedTimer.push()
			case 1:
				Settings.hideDescriptionInWatchDetail = !Settings.hideDescriptionInWatchDetail
			default: break
			}
		} else if section == SettingsSection.Comments {
			switch originalIndex {
			case 0:
				Settings.showCommentsEverywhere = !Settings.showCommentsEverywhere
				settingsChangedTimer.push()
			case 1:
				Settings.hideUncommentedItems = !Settings.hideUncommentedItems
				settingsChangedTimer.push()
			case 2:
				Settings.autoMoveOnCommentMentions = !Settings.autoMoveOnCommentMentions
				settingsChangedTimer.push()
			case 3:
				Settings.autoMoveOnTeamMentions = !Settings.autoMoveOnTeamMentions
				settingsChangedTimer.push()
			case 4:
				Settings.moveNewItemsInOwnReposToMentioned = !Settings.moveNewItemsInOwnReposToMentioned
				settingsChangedTimer.push()
			case 5:
				Settings.openPrAtFirstUnreadComment = !Settings.openPrAtFirstUnreadComment
			case 6:
				performSegueWithIdentifier("showBlacklist", sender: self)
			case 7:
				Settings.disableAllCommentNotifications = !Settings.disableAllCommentNotifications
			case 8:
				Settings.assumeReadItemIfUserHasNewerComments = !Settings.assumeReadItemIfUserHasNewerComments
			default: break
			}
		} else if section == SettingsSection.Repos {
			pickerName = setting.title
			valuesToPush = RepoDisplayPolicy.labels
			selectedIndexPath = indexPath
			switch originalIndex {
			case 0:
				previousValue = Settings.displayPolicyForNewPrs
			case 1:
				previousValue = Settings.displayPolicyForNewIssues
			default: break
			}
			performSegueWithIdentifier("showPicker", sender: self)
		} else if section == SettingsSection.StausesAndLabels {
			switch originalIndex {
			case 0:
				Settings.showStatusItems = !Settings.showStatusItems
				api.resetAllStatusChecks()
				if Settings.showStatusItems {
					ApiServer.resetSyncOfEverything()
				}
				settingsChangedTimer.push()
				preferencesDirty = true
			case 1:
				selectedIndexPath = indexPath
				pickerName = setting.title
				var values = [String]()
				var count = 1
				values.append("Every refresh")
				previousValue = 0
				for f in 2..<100 {
					if f == Settings.statusItemRefreshInterval { previousValue = count }
					values.append("Every \(f) refreshes")
					count += 1
				}
				valuesToPush = values
				performSegueWithIdentifier("showPicker", sender: self)
			case 2:
				Settings.showLabels = !Settings.showLabels
				api.resetAllLabelChecks()
				if Settings.showLabels {
					ApiServer.resetSyncOfEverything()
				}
				settingsChangedTimer.push()
				preferencesDirty = true
			case 3:
				selectedIndexPath = indexPath
				pickerName = setting.title
				var values = [String]()
				var count = 1
				values.append("Every refresh")
				previousValue = 0
				for f in 2..<100 {
					if f == Settings.labelRefreshInterval { previousValue = count }
					values.append("Every \(f) refreshes")
					count += 1
				}
				valuesToPush = values
				performSegueWithIdentifier("showPicker", sender: self)
			case 4:
				Settings.notifyOnStatusUpdates = !Settings.notifyOnStatusUpdates
			case 5:
				Settings.notifyOnStatusUpdatesForAllPrs = !Settings.notifyOnStatusUpdatesForAllPrs
			case 6:
				Settings.hidePrsThatArentPassing = !Settings.hidePrsThatArentPassing
				settingsChangedTimer.push()
			case 7:
				Settings.hidePrsThatDontPassOnlyInAll = !Settings.hidePrsThatDontPassOnlyInAll
				settingsChangedTimer.push()
			default: break
			}
		} else if section == SettingsSection.History {
			switch originalIndex {
			case 0:
				selectedIndexPath = indexPath
				previousValue = Settings.mergeHandlingPolicy
				pickerName = setting.title
				valuesToPush = HandlingPolicy.labels
				performSegueWithIdentifier("showPicker", sender: self)
			case 1:
				selectedIndexPath = indexPath
				previousValue = Settings.closeHandlingPolicy
				pickerName = setting.title
				valuesToPush = HandlingPolicy.labels
				performSegueWithIdentifier("showPicker", sender: self)
			case 2:
				Settings.dontKeepPrsMergedByMe = !Settings.dontKeepPrsMergedByMe
			default: break
			}
		} else if section == SettingsSection.Confirm {
			switch originalIndex {
			case 0:
				Settings.dontAskBeforeWipingMerged = !Settings.dontAskBeforeWipingMerged
			case 1:
				Settings.dontAskBeforeWipingClosed = !Settings.dontAskBeforeWipingClosed
			default: break
			}
		} else if section == SettingsSection.Sort {
			switch originalIndex {
			case 0:
				Settings.sortDescending = !Settings.sortDescending
				settingsChangedTimer.push()
			case 1:
				selectedIndexPath = indexPath
				previousValue = Settings.sortMethod
				pickerName = setting.title
				valuesToPush = Settings.sortDescending ? SortingMethod.reverseTitles : SortingMethod.normalTitles
				performSegueWithIdentifier("showPicker", sender: self)
			case 2:
				Settings.groupByRepo = !Settings.groupByRepo
				settingsChangedTimer.push()
			default: break
			}
		} else if section == SettingsSection.Misc {
			switch originalIndex {
			case 0:
				Settings.logActivityToConsole = !Settings.logActivityToConsole
				if Settings.logActivityToConsole {
					showMessage("Warning", "Logging is a feature meant to aid error reporting, having it constantly enabled will cause this app to be less responsive and use more battery")
				}
			case 1:
				Settings.dumpAPIResponsesInConsole = !Settings.dumpAPIResponsesInConsole
				if Settings.dumpAPIResponsesInConsole {
					showMessage("Warning", "Logging is a feature meant to aid error reporting, having it constantly enabled will cause this app to be less responsive and use more battery")
				}
			default: break
			}
		}
		reload()
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return filteredItemsForTableSection(section).count
	}

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return filteredSections()[section].title()
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return filteredSections().count
	}

	private func filteredItemsForTableSection(section: Int) -> [Setting] {
		let sec = filteredSections()[section]
		let searchText = searchBar.text?.trim()
		return settings.filter{ $0.section == sec && $0.isRelevantTo(searchText, showingHelp: showHelp) }
	}

	private func filteredSections() -> [SettingsSection] {
		let searchText = searchBar.text?.trim()
		let matchingSettings = settings.filter{ $0.isRelevantTo(searchText, showingHelp: showHelp) }
		var matchingSections = [SettingsSection]()
		matchingSettings.forEach {
			let s = $0.section
			if !matchingSections.contains(s) {
				matchingSections.append(s)
			}
		}
		return matchingSections
	}

	private var sizer: AdvancedSettingsCell?
	private var heightCache = [NSIndexPath : CGFloat]()
	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if sizer == nil {
			sizer = tableView.dequeueReusableCellWithIdentifier("Cell") as? AdvancedSettingsCell
		} else if let h = heightCache[indexPath] {
			//DLog("using cached height for %d - %d", indexPath.section, indexPath.row)
			return h
		}
		configureCell(sizer!, indexPath: indexPath)
		let h = sizer!.systemLayoutSizeFittingSize(CGSizeMake(tableView.bounds.width, UILayoutFittingCompressedSize.height),
			withHorizontalFittingPriority: UILayoutPriorityRequired,
			verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
		heightCache[indexPath] = h
		return h
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let p = segue.destinationViewController as? PickerViewController {
			p.delegate = self
			p.title = pickerName
			p.values = valuesToPush
			p.previousValue = previousValue
			pickerName = nil
			valuesToPush = nil
		}
	}

	func pickerViewController(picker: PickerViewController, didSelectIndexPath: NSIndexPath) {
		if let sip = selectedIndexPath {
			if sip.section == SettingsSection.Refresh.rawValue {
				if sip.row == 0 {
					Settings.refreshPeriod = Float(didSelectIndexPath.row*10+60)
				} else if sip.row == 1 {
					Settings.backgroundRefreshPeriod = Float((didSelectIndexPath.row*5+5)*60)
				} else if sip.row == 2 {
					Settings.newRepoCheckPeriod = Float(didSelectIndexPath.row+2)
				}
			} else if sip.section == SettingsSection.Display.rawValue {
				Settings.assignedPrHandlingPolicy = didSelectIndexPath.row
				settingsChangedTimer.push()
			} else if sip.section == SettingsSection.Sort.rawValue {
				Settings.sortMethod = Int(didSelectIndexPath.row)
				settingsChangedTimer.push()
			} else if sip.section == SettingsSection.Repos.rawValue {
				if sip.row == 0 {
					Settings.displayPolicyForNewPrs = Int(didSelectIndexPath.row)
				} else if sip.row == 1 {
					Settings.displayPolicyForNewIssues = Int(didSelectIndexPath.row)
				}
			} else if sip.section == SettingsSection.History.rawValue {
				if sip.row == 0 {
					Settings.mergeHandlingPolicy = Int(didSelectIndexPath.row)
				} else if sip.row == 1 {
					Settings.closeHandlingPolicy = Int(didSelectIndexPath.row)
				}
			} else if sip.section == SettingsSection.StausesAndLabels.rawValue {
				if sip.row == 1 {
					Settings.statusItemRefreshInterval = Int(didSelectIndexPath.row+1)
				} else  if sip.row == 3 {
					Settings.labelRefreshInterval = Int(didSelectIndexPath.row+1)
				}
			}
			reload()
			selectedIndexPath = nil
		}
	}

	/////////////////// Import / Export

	private var tempUrl: NSURL?

	func importSelected(sender: UIBarButtonItem) {
		tempUrl = nil

		let menu = UIDocumentPickerViewController(documentTypes: ["com.housetrip.mobile.trailer.ios.settings"], inMode: UIDocumentPickerMode.Import)
		menu.delegate = self
		popupManager.showPopoverFromViewController(self, fromItem: sender, viewController: menu)
	}

	func exportSelected(sender: UIBarButtonItem) {
		let tempFilePath = NSTemporaryDirectory().stringByAppendingPathComponent("Trailer Settings (iOS).trailerSettings")
		tempUrl = NSURL(fileURLWithPath: tempFilePath)
		Settings.writeToURL(tempUrl!)

		let menu = UIDocumentPickerViewController(URL: tempUrl!, inMode: UIDocumentPickerMode.ExportToService)
		menu.delegate = self
		popupManager.showPopoverFromViewController(self, fromItem: sender, viewController: menu)
	}

	func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL) {
		if tempUrl == nil {
			DLog("Will import settings from %@", url.absoluteString)
			settingsManager.loadSettingsFrom(url, confirmFromView: self) { [weak self] confirmed in
				if confirmed {
					self?.dismissViewControllerAnimated(false, completion: nil)
				}
				self?.documentInteractionCleanup()
			}
		} else {
			DLog("Saved settings to %@", url.absoluteString)
			documentInteractionCleanup()
		}
	}

	func documentPickerWasCancelled(controller: UIDocumentPickerViewController) {
		DLog("Document picker cancelled")
		documentInteractionCleanup()
	}

	func documentInteractionCleanup() {
		if let t = tempUrl {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(t)
			} catch {
				DLog("Temporary file cleanup error: %@", (error as NSError).localizedDescription)
			}
			tempUrl = nil
		}
	}
}
