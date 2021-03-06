
import UIKit
import CoreData

final class RespositoriesViewController: UITableViewController, UISearchBarDelegate, NSFetchedResultsControllerDelegate {

	// Filtering
	@IBOutlet weak var searchBar: UISearchBar!
	private var searchTimer: PopTimer!
	private var _fetchedResultsController: NSFetchedResultsController?

	@IBOutlet weak var actionsButton: UIBarButtonItem!

	@IBAction func done(sender: UIBarButtonItem) {
		if preferencesDirty {
			app.startRefresh()
		}
		dismissViewControllerAnimated(true, completion: nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		searchTimer = PopTimer(timeInterval: 0.5) { [weak self] in
			self?.reloadData()
		}
	}

	override func viewDidAppear(animated: Bool) {
		actionsButton.enabled = ApiServer.someServersHaveAuthTokensInMoc(mainObjectContext)
		if actionsButton.enabled && fetchedResultsController.fetchedObjects?.count==0 {
			refreshList()
		} else if let selectedIndex = tableView.indexPathForSelectedRow {
			tableView.deselectRowAtIndexPath(selectedIndex, animated: true)
		}
		super.viewDidAppear(animated)
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.setToolbarHidden(false, animated: animated)
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		self.navigationController?.setToolbarHidden(true, animated: animated)
	}

	@IBAction func actionSelected(sender: UIBarButtonItem) {
		refreshList()
	}

	@IBAction func setAllPrsSelected(sender: UIBarButtonItem) {
		if let ip = tableView.indexPathForSelectedRow {
			tableView.deselectRowAtIndexPath(ip, animated: false)
		}
		performSegueWithIdentifier("showRepoSelection", sender: self)
	}

	private func refreshList() {
		self.navigationItem.rightBarButtonItem?.enabled = false
		let originalName = navigationItem.title
		navigationItem.title = "Loading..."
		actionsButton.enabled = false
		tableView.userInteractionEnabled = false
		tableView.alpha = 0.5

		let tempContext = DataManager.childContext()
		api.fetchRepositoriesToMoc(tempContext) { [weak self] in
			if ApiServer.shouldReportRefreshFailureInMoc(tempContext) {
				var errorServers = [String]()
				for apiServer in ApiServer.allApiServersInMoc(tempContext) {
					if apiServer.goodToGo && !apiServer.syncIsGood {
						errorServers.append(S(apiServer.label))
					}
				}
				let serverNames = errorServers.joinWithSeparator(", ")
				showMessage("Error", "Could not refresh repository list from \(serverNames), please ensure that the tokens you are using are valid")
			} else {
				try! tempContext.save()
			}
			self?.navigationItem.title = originalName
			self?.actionsButton.enabled = ApiServer.someServersHaveAuthTokensInMoc(mainObjectContext)
			self?.tableView.alpha = 1.0
			self?.tableView.userInteractionEnabled = true
			preferencesDirty = true
			self?.navigationItem.rightBarButtonItem?.enabled = true
		}
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return fetchedResultsController.sections?.count ?? 0
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! RepoCell
		configureCell(cell, atIndexPath: indexPath)
		return cell
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if let indexPath = tableView.indexPathForSelectedRow,
			repo = fetchedResultsController.objectAtIndexPath(indexPath) as? Repo,
			vc = segue.destinationViewController as? RepoSettingsViewController {
			vc.repo = repo
		}
	}

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section==1 {
			return "Forked Repos"
		} else {
			let repo = fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: 0, inSection: section)) as! Repo
			if (repo.fork?.boolValue ?? false) {
				return "Forked Repos"
			} else {
				return "Parent Repos"
			}
		}
	}

	private var fetchedResultsController: NSFetchedResultsController {
		if let f = _fetchedResultsController {
			return f
		}

		let fetchRequest = NSFetchRequest(entityName: "Repo")
		if let text = searchBar.text where !text.isEmpty {
			fetchRequest.predicate = NSPredicate(format: "fullName contains [cd] %@", text)
		}
		fetchRequest.fetchBatchSize = 20
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "fork", ascending: true), NSSortDescriptor(key: "fullName", ascending: true)]

		let fc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: mainObjectContext, sectionNameKeyPath: "fork", cacheName: nil)
		fc.delegate = self
		_fetchedResultsController = fc

		try! fc.performFetch()
		return fc
	}

	func controllerWillChangeContent(controller: NSFetchedResultsController) {
		tableView.beginUpdates()
	}

	func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {

		heightCache.removeAll()

		switch(type) {
		case .Insert:
			tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
		case .Delete:
			tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
		case .Update:
			tableView.reloadSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
		default:
			break
		}
	}

	func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {

		heightCache.removeAll()

		switch(type) {
		case .Insert:
			tableView.insertRowsAtIndexPaths([newIndexPath ?? indexPath!], withRowAnimation: .Automatic)
		case .Delete:
			tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation:.Automatic)
		case .Update:
			if let cell = tableView.cellForRowAtIndexPath(newIndexPath ?? indexPath!) as? RepoCell {
				configureCell(cell, atIndexPath: newIndexPath ?? indexPath!)
			}
		case .Move:
			tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation:.Automatic)
			if let n = newIndexPath {
				tableView.insertRowsAtIndexPaths([n], withRowAnimation:.Automatic)
			}
		}
	}

	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		tableView.endUpdates()
	}

	private func configureCell(cell: RepoCell, atIndexPath: NSIndexPath) {
		let repo = fetchedResultsController.objectAtIndexPath(atIndexPath) as! Repo

		let titleColor = repo.shouldSync ? UIColor.blackColor() : UIColor.lightGrayColor()
		let titleAttributes = [ NSForegroundColorAttributeName: titleColor ]

		let title = NSMutableAttributedString(attributedString: NSAttributedString(string: S(repo.fullName), attributes: titleAttributes))
		title.appendAttributedString(NSAttributedString(string: "\n", attributes: titleAttributes))
		let groupTitle = groupTitleForRepo(repo)
		title.appendAttributedString(groupTitle)

		cell.titleLabel.attributedText = title
		let prTitle = prTitleForRepo(repo)
		let issuesTitle = issueTitleForRepo(repo)
		let hidingTitle = hidingTitleForRepo(repo)

		cell.prLabel.attributedText = prTitle
		cell.issuesLabel.attributedText = issuesTitle
		cell.hidingLabel.attributedText = hidingTitle
		cell.accessibilityLabel = "\(title), \(prTitle.string), \(issuesTitle.string), \(hidingTitle.string), \(groupTitle.string)"
	}

	private var sizer: RepoCell?
	private var heightCache = [NSIndexPath : CGFloat]()
	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if sizer == nil {
			sizer = tableView.dequeueReusableCellWithIdentifier("Cell") as? RepoCell
		} else if let h = heightCache[indexPath] {
			//DLog("using cached height for %d - %d", indexPath.section, indexPath.row)
			return h
		}
		configureCell(sizer!, atIndexPath: indexPath)
		let h = sizer!.systemLayoutSizeFittingSize(CGSizeMake(tableView.bounds.width, UILayoutFittingCompressedSize.height),
			withHorizontalFittingPriority: UILayoutPriorityRequired,
			verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
		heightCache[indexPath] = h
		return h
	}

	private func titleForRepo(repo: Repo) -> NSAttributedString {

		let fullName = S(repo.fullName)
		let text = (repo.inaccessible?.boolValue ?? false) ? "\(fullName) (inaccessible)" : fullName
		let color = repo.shouldSync ? UIColor.darkTextColor() : UIColor.lightGrayColor()
		return NSAttributedString(string: text, attributes: [ NSForegroundColorAttributeName: color ])
	}

	private func prTitleForRepo(repo: Repo) -> NSAttributedString {

		let policy = RepoDisplayPolicy(rawValue: repo.displayPolicyForPrs?.integerValue ?? 0) ?? .Hide
		let attributes = attributesForEntryWithPolicy(policy)
		return NSAttributedString(string: "PR Sections: \(policy.name())", attributes: attributes)
	}

	private func issueTitleForRepo(repo: Repo) -> NSAttributedString {

		let policy = RepoDisplayPolicy(rawValue: repo.displayPolicyForIssues?.integerValue ?? 0) ?? .Hide
		let attributes = attributesForEntryWithPolicy(policy)
		return NSAttributedString(string: "Issue Sections: \(policy.name())", attributes: attributes)
	}

	private func groupTitleForRepo(repo: Repo) -> NSAttributedString {
		if let l = repo.groupLabel {
			return NSAttributedString(string: "Group: \(l)", attributes: [
				NSForegroundColorAttributeName : UIColor.darkGrayColor(),
				NSFontAttributeName: UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
				])
		} else {
			return NSAttributedString(string: "Ungrouped", attributes: [
				NSForegroundColorAttributeName : UIColor.lightGrayColor(),
				NSFontAttributeName: UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
				])
		}
	}

	private func hidingTitleForRepo(repo: Repo) -> NSAttributedString {

		let policy = RepoHidingPolicy(rawValue: repo.itemHidingPolicy?.integerValue ?? 0) ?? .NoHiding
		let attributes = attributesForEntryWithPolicy(policy)
		return NSAttributedString(string: policy.name(), attributes: attributes)
	}

	private func attributesForEntryWithPolicy(policy: RepoDisplayPolicy) -> [String : AnyObject] {
		return [
			NSFontAttributeName: UIFont.systemFontOfSize(UIFont.smallSystemFontSize()-1.0),
			NSForegroundColorAttributeName: policy.color()
		]
	}

	private func attributesForEntryWithPolicy(policy: RepoHidingPolicy) -> [String : AnyObject] {
		return [
			NSFontAttributeName: UIFont.systemFontOfSize(UIFont.smallSystemFontSize()-1.0),
			NSForegroundColorAttributeName: policy.color()
		]
	}

	///////////////////////////// filtering

	private func reloadData() {

		heightCache.removeAll()

		let currentIndexes = NSIndexSet(indexesInRange: NSMakeRange(0, fetchedResultsController.sections?.count ?? 0))

		_fetchedResultsController = nil

		let dataIndexes = NSIndexSet(indexesInRange: NSMakeRange(0, fetchedResultsController.sections?.count ?? 0))

		let removedIndexes = currentIndexes.indexesPassingTest { (idx, _) -> Bool in
			return !dataIndexes.containsIndex(idx)
		}
		let addedIndexes = dataIndexes.indexesPassingTest { (idx, _) -> Bool in
			return !currentIndexes.containsIndex(idx)
		}
		let untouchedIndexes = dataIndexes.indexesPassingTest { (idx, _) -> Bool in
			return !(removedIndexes.containsIndex(idx) || addedIndexes.containsIndex(idx))
		}

		tableView.beginUpdates()
		if removedIndexes.count > 0 {
			tableView.deleteSections(removedIndexes, withRowAnimation:.Automatic)
		}
		if untouchedIndexes.count > 0 {
			tableView.reloadSections(untouchedIndexes, withRowAnimation:.Automatic)
		}
		if addedIndexes.count > 0 {
			tableView.insertSections(addedIndexes, withRowAnimation:.Automatic)
		}
		tableView.endUpdates()
	}

	override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
		if searchBar!.isFirstResponder() {
			searchBar!.resignFirstResponder()
		}
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
}
