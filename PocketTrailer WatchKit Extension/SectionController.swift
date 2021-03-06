
import WatchKit
import WatchConnectivity

final class SectionController: CommonController {

	@IBOutlet weak var table: WKInterfaceTable!
	@IBOutlet weak var statusLabel: WKInterfaceLabel!

	private var rowControllers = [PopulatableRow]()

	override func awakeWithContext(context: AnyObject?) {
		_statusLabel = statusLabel
		_table = table
		super.awakeWithContext(context)
	}

	override func willActivate() {
		super.willActivate()
		updateUI()
	}

	override func showLoadingFeedback() -> Bool {
		return false
	}

	@IBAction func clearMergedSelected() {
		showStatus("Clearing merged", hideTable: true)
		requestData("clearAllMerged")
	}

	@IBAction func clearClosedSelected() {
		showStatus("Clearing closed", hideTable: true)
		requestData("clearAllClosed")
	}

	@IBAction func markAllReadSelected() {
		showStatus("Marking all as read", hideTable: true)
		requestData("markEverythingRead")
	}

	@IBAction func refreshSelected() {
		showStatus("Refreshing", hideTable: true)
		requestData("refresh")
	}

	override func requestData(command: String?) {
		if let c = command {
			sendRequest(["command": c])
		} else if WCSession.defaultSession().receivedApplicationContext["overview"] != nil {
			updateUI()
		} else {
			requestData("needsOverview")
		}
	}

	override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
		let r = rowControllers[rowIndex] as! SectionRow
		let section = r.section?.rawValue ?? -1
		pushControllerWithName("ListController", context: [
			SECTION_KEY: section,
			TYPE_KEY: r.type!,
			UNREAD_KEY: section == -1,
			GROUP_KEY: r.groupLabel!,
			API_URI_KEY: r.apiServerUri! ] )
	}

	override func updateFromData(response: [NSString : AnyObject]) {
		super.updateFromData(response)
		updateUI()
	}

	private func sectionFromApi(apiName: String) -> Section {
		return Section(rawValue: Section.apiTitles.indexOf(apiName)!)!
	}

	private func updateUI() {

		rowControllers.removeAll(keepCapacity: false)

		func addSectionsFor(entry: [String : AnyObject], itemType: String, label: String, apiServerUri: String, header: String, showEmptyDescriptions: Bool) {
			let items = entry[itemType] as! [String : AnyObject]
			let totalItems = items["total"] as! Int
			let prefix = label.isEmpty ? "" : "\(label): "
			if totalItems > 0 {
				let pt = TitleRow()
				pt.title = "\(prefix)\(totalItems) \(header)"
				rowControllers.append(pt)
				var totalUnread = 0
				for itemSection in Section.apiTitles {
					if itemSection == Section.None.apiName() { continue }

					if let section = items[itemSection], count = section["total"] as? Int, unread = section["unread"] as? Int where count > 0 {
						let s = SectionRow()
						s.section = sectionFromApi(itemSection)
						s.totalCount = count
						s.unreadCount = unread
						s.type = itemType
						s.groupLabel = label
						s.apiServerUri = apiServerUri
						rowControllers.append(s)

						totalUnread += unread
					}
				}
				if totalUnread > 0 {
					let s = SectionRow()
					s.section = nil
					s.totalCount = 0
					s.unreadCount = totalUnread
					s.type = itemType
					s.groupLabel = label
					s.apiServerUri = apiServerUri
					rowControllers.append(s)
				}

			} else if showEmptyDescriptions {
				let error = (items["error"] as? String) ?? ""
				let pt = TitleRow()
				pt.title = "\(prefix)\(header): \(error)"
				rowControllers.append(pt)
			}
		}

		if let result = WCSession.defaultSession().receivedApplicationContext["overview"] as? [String : AnyObject] {

			let views = result["views"]
			let showEmptyDescriptions = views?.count == 1
			for v in views as! [[String : AnyObject]] {
				let label = v["title"] as! String
				let apiServerUri = v["apiUri"] as! String
				addSectionsFor(v, itemType: "prs", label: label, apiServerUri: apiServerUri, header: "Pull Requests", showEmptyDescriptions: showEmptyDescriptions)
				addSectionsFor(v, itemType: "issues", label: label, apiServerUri: apiServerUri, header: "Issues", showEmptyDescriptions: showEmptyDescriptions)
			}

			table.setRowTypes(rowControllers.map({ $0.rowType() }))

			var index = 0
			for rc in rowControllers {
				if let c = table.rowControllerAtIndex(index) as? PopulatableRow {
					c.populateFrom(rc)
				}
				index += 1
			}

			showStatus("", hideTable: false)
			(WKExtension.sharedExtension().delegate as! ExtensionDelegate).updateComplications()
		} else {
			showStatus("There is no data from Trailer yet, please run it once on your iOS device", hideTable: true)
		}
	}
}
