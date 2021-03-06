
import UIKit

let settingsManager = SettingsManager()

final class SettingsManager {

	private func loadSettingsFrom(url: NSURL) {
		if Settings.readFromURL(url) {
			atNextEvent {

				popupManager.getMasterController().resetView()

				preferencesDirty = true
				Settings.lastSuccessfulRefresh = nil

				atNextEvent {
					app.startRefreshIfItIsDue()
				}
			}
		} else {
			atNextEvent {
				showMessage("Error", "These settings could not be imported due to an error")
			}
		}
	}

	func loadSettingsFrom(url: NSURL, confirmFromView: UIViewController?, withCompletion: ((Bool)->Void)?) {
		if let v = confirmFromView {
			let a = UIAlertController(title: "Import these settings?", message: "This will overwrite all your current settings, are you sure?", preferredStyle: .Alert)
			a.addAction(UIAlertAction(title: "Yes", style: .Destructive) { [weak self] action in
				self?.loadSettingsFrom(url)
				withCompletion?(true)
			})
			a.addAction(UIAlertAction(title: "No", style: .Cancel) { action in
				withCompletion?(false)
			})
			atNextEvent {
				v.presentViewController(a, animated: true, completion: nil)
			}
		} else {
			loadSettingsFrom(url)
			withCompletion?(true)
		}
	}
}
