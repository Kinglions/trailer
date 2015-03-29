
import WatchKit
import Foundation

let shortDateFormatter = { () -> NSDateFormatter in
	let d = NSDateFormatter()
	d.dateStyle = NSDateFormatterStyle.ShortStyle
	d.timeStyle = NSDateFormatterStyle.ShortStyle
	return d
	}()

class PRDetailController: WKInterfaceController {

	@IBOutlet weak var table: WKInterfaceTable!

	var pullRequest: PullRequest?
	var issue: Issue?
	var refreshWhenBack = false

	override func awakeWithContext(context: AnyObject?) {
		super.awakeWithContext(context)

		let c = context as! NSDictionary
		issue = c[ISSUE_KEY] as? Issue
		pullRequest = c[PULL_REQUEST_KEY] as? PullRequest

		buildUI()
	}

	override func willActivate() {
		if refreshWhenBack {
			if let p = pullRequest {
				mainObjectContext.refreshObject(p, mergeChanges: false)
			}
			if let i = issue {
				mainObjectContext.refreshObject(i, mergeChanges: false)
			}
			buildUI()
			refreshWhenBack = false
		}
		super.willActivate()
	}

	override func didDeactivate() {
		super.didDeactivate()
	}

	@IBAction func refreshSelected() {
		refreshWhenBack = true
		presentControllerWithName("Command Controller", context: ["command": "refresh"])
	}

	@IBAction func openOnDeviceSelected() {
		if let i = issue?.objectID.URIRepresentation().absoluteString {
			presentControllerWithName("Command Controller", context: ["command": "openissue", "id": i])
		} else if let p = pullRequest?.objectID.URIRepresentation().absoluteString {
			presentControllerWithName("Command Controller", context: ["command": "openpr", "id": p])
		}
	}

	override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
		let r: AnyObject? = table.rowControllerAtIndex(rowIndex)
		if let
			c = r as? CommentRow,
			commentId = c.commentId
		{
			presentControllerWithName("Command Controller", context: ["command": "opencomment", "id": commentId])
		}
	}

	private func buildUI() {

		var displayedStatuses: [PRStatus]?

		if let p = pullRequest {
			self.setTitle(p.title)
			displayedStatuses = p.displayedStatuses()
		}
		if let i = issue {
			self.setTitle(i.title)
		}

		var rowTypes = [String]()

		for s in displayedStatuses ?? [] {
			rowTypes.append("StatusRow")
		}

		var showDescription = false

		if let p = pullRequest {

			showDescription = !(Settings.hideDescriptionInWatchDetail || (p.body ?? "").isEmpty)
			if showDescription {
				rowTypes.append("LabelRow")
			}

			for c in 0..<p.comments.count {
				rowTypes.append("CommentRow")
			}

		} else if let i = issue {

			showDescription = !(Settings.hideDescriptionInWatchDetail || (i.body ?? "").isEmpty)
			if showDescription {
				rowTypes.append("LabelRow")
			}

			for c in 0..<i.comments.count {
				rowTypes.append("CommentRow")
			}
		}

		table.setRowTypes(rowTypes)

		var index = 0

		for s in displayedStatuses ?? [] {
			let controller = table.rowControllerAtIndex(index++) as! StatusRow
			controller.labelL.setText(s.displayText())
			let color = s.colorForDarkDisplay()
			controller.labelL.setTextColor(color)
			controller.margin.setBackgroundColor(color)
		}

		if let p = pullRequest {
			if showDescription==true {
				(table.rowControllerAtIndex(index++) as! LabelRow).labelL.setText(p.body)
			}
			var unreadCount = p.unreadComments?.integerValue ?? 0
			for c in p.sortedComments(NSComparisonResult.OrderedDescending) {
				let controller = table.rowControllerAtIndex(index++) as! CommentRow
				controller.usernameL.setText((c.userName ?? "(unknown)") + "\n" + shortDateFormatter.stringFromDate(c.createdAt ?? NSDate()))
				controller.commentL.setText(c.body)

				controller.commentId = c.objectID.URIRepresentation().absoluteString

				if unreadCount > 0 {
					unreadCount--
					controller.margin.setBackgroundColor(UIColor.redColor())
				} else {
					controller.margin.setBackgroundColor(UIColor.lightGrayColor())
				}
			}
		} else if let i = issue {
			if showDescription==true {
				(table.rowControllerAtIndex(index++) as! LabelRow).labelL.setText(i.body)
			}
			var unreadCount = i.unreadComments?.integerValue ?? 0
			for c in i.sortedComments(NSComparisonResult.OrderedDescending) {
				let controller = table.rowControllerAtIndex(index++) as! CommentRow
				controller.usernameL.setText((c.userName ?? "(unknown)") + "\n" + shortDateFormatter.stringFromDate(c.createdAt ?? NSDate()))
				controller.commentL.setText(c.body)

				controller.commentId = c.objectID.URIRepresentation().absoluteString

				if unreadCount > 0 {
					unreadCount--
					controller.margin.setBackgroundColor(UIColor.redColor())
				} else {
					controller.margin.setBackgroundColor(UIColor.lightGrayColor())
				}
			}
		}
	}
}
