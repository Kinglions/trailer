
import WatchKit

class CommentRow: NSObject {
    @IBOutlet weak var usernameL: WKInterfaceLabel!
    @IBOutlet weak var commentL: WKInterfaceLabel!
	@IBOutlet weak var usernameBackground: WKInterfaceGroup!
	@IBOutlet weak var margin: WKInterfaceGroup!
	var commentId: String?
}
