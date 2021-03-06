
import UIKit
import CoreData

final class ServersViewController: UITableViewController {

	private var selectedServerId: NSManagedObjectID?
	private var allServers: [ApiServer]!

	@IBAction func doneSelected() {
		if preferencesDirty {
			app.startRefresh()
		}
		dismissViewControllerAnimated(true, completion: nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		clearsSelectionOnViewWillAppear = true
		NSNotificationCenter.defaultCenter().addObserver(tableView, selector: #selector(UITableView.reloadData), name: REFRESH_ENDED_NOTIFICATION, object: nil)
	}

	deinit {
		if tableView != nil {
			NSNotificationCenter.defaultCenter().removeObserver(tableView)
		}
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		allServers = ApiServer.allApiServersInMoc(mainObjectContext)
		tableView.reloadData()
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return allServers.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("ServerCell", forIndexPath: indexPath)
		if let T = cell.textLabel, D = cell.detailTextLabel {
			let a = allServers[indexPath.row]
			if S(a.authToken).isEmpty {
				T.textColor = UIColor.redColor()
				T.text = "\(S(a.label)) (needs token!)"
			} else if !a.syncIsGood {
				T.textColor = UIColor.redColor()
				T.text = "\(S(a.label)) (last sync failed)"
			} else {
				T.textColor = UIColor.darkTextColor()
				T.text = a.label
			}
			if a.requestsLimit==nil || a.requestsLimit!.doubleValue==0.0 {
				D.text = nil
			} else {
				let total = a.requestsLimit?.doubleValue ?? 0
				let used = total - (a.requestsRemaining?.doubleValue ?? 0)
				if a.resetDate != nil {
					D.text = String(format:"%.01f%% API used (%.0f / %.0f requests)\nNext reset: %@", 100*used/total, used, total, shortDateFormatter.stringFromDate(a.resetDate!))
				} else {
					D.text = String(format:"%.01f%% API used (%.0f / %.0f requests)", 100*used/total, used, total)
				}
			}
		}
		return cell
	}

	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == UITableViewCellEditingStyle.Delete {
			let a = allServers[indexPath.row]
			allServers.removeAtIndex(indexPath.row)
			mainObjectContext.deleteObject(a)
			DataManager.saveDB()
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
		}
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let a = allServers[indexPath.row]
		selectedServerId = a.objectID
		performSegueWithIdentifier("editServer", sender: self)
	}

	@IBAction func newServer() {
		performSegueWithIdentifier("editServer", sender: self)
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let sd = segue.destinationViewController as? ServerDetailViewController {
			sd.serverId = selectedServerId
			selectedServerId = nil
		}
	}
}
