
final class PullRequestCell: TrailerCell {

	init(pullRequest: PullRequest) {

		super.init(frame: NSZeroRect)

		dataItemId = pullRequest.objectID
		detailFont = NSFont.menuFontOfSize(10.0)
		titleFont = NSFont.menuFontOfSize(13.0)

		unselectedTitleColor = goneDark ? NSColor.controlHighlightColor() : NSColor.controlTextColor()

		let _commentsNew = pullRequest.unreadComments?.integerValue ?? 0
		let _commentsTotal = pullRequest.totalComments?.integerValue ?? 0

		let _title = pullRequest.titleWithFont(titleFont, labelFont: detailFont, titleColor: unselectedTitleColor)
		let _subtitle = pullRequest.subtitleWithFont(detailFont, lightColor: NSColor.grayColor(), darkColor: NSColor.darkGrayColor())

		var W = MENU_WIDTH-LEFTPADDING-app.scrollBarWidth

		let showUnpin = (pullRequest.condition?.integerValue != ItemCondition.Open.rawValue) || pullRequest.markUnmergeable
		if showUnpin { W -= REMOVE_BUTTON_WIDTH } else { W -= 4.0 }

		let showAvatar = !S(pullRequest.userAvatarUrl).isEmpty && !Settings.hideAvatars
		if showAvatar { W -= AVATAR_SIZE+AVATAR_PADDING } else { W += 4.0 }

		let titleHeight = ceil(_title.boundingRectWithSize(CGSizeMake(W-4.0, CGFloat.max), options: stringDrawingOptions).size.height)
		let subtitleHeight = ceil(_subtitle.boundingRectWithSize(CGSizeMake(W-4.0, CGFloat.max), options: stringDrawingOptions).size.height+4.0)

		var statusRects = [NSValue]()
		var statuses: [PRStatus]? = nil
		var bottom: CGFloat, CELL_PADDING: CGFloat
		var statusBottom = CGFloat(0)

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.headIndent = 92.0

		var statusAttributes = [String : AnyObject]()
		statusAttributes[NSFontAttributeName] = NSFont(name: "Monaco", size: 9)
		statusAttributes[NSParagraphStyleAttributeName] = paragraphStyle

		if Settings.showStatusItems {
			CELL_PADDING = 10
			bottom = ceil(CELL_PADDING * 0.5)
			statuses = pullRequest.displayedStatuses
			for s in statuses! {
				let H = ceil(s.displayText.boundingRectWithSize(CGSizeMake(W, CGFloat.max),
					options: stringDrawingOptions,
					attributes: statusAttributes).size.height)
				statusRects.append(NSValue(rect: NSMakeRect(LEFTPADDING, bottom+statusBottom, W, H)))
				statusBottom += H
			}
		} else {
			CELL_PADDING = 6.0
			bottom = ceil(CELL_PADDING * 0.5)
		}

		frame = NSMakeRect(0, 0, MENU_WIDTH, titleHeight+subtitleHeight+statusBottom+CELL_PADDING)
		let faded = pullRequest.shouldSkipNotifications
		addCounts(_commentsTotal, _commentsNew, faded)

		var titleRect = NSMakeRect(LEFTPADDING, subtitleHeight+bottom+statusBottom, W, titleHeight)
		var dateRect = NSMakeRect(LEFTPADDING, statusBottom+bottom, W, subtitleHeight)
		var pinRect = NSMakeRect(LEFTPADDING+W, floor((bounds.size.height-24)*0.5), REMOVE_BUTTON_WIDTH-10, 24)

		let shift: CGFloat
		if showAvatar {
			let userImage = AvatarView(
				frame: NSMakeRect(LEFTPADDING, bounds.size.height-AVATAR_SIZE-7.0, AVATAR_SIZE, AVATAR_SIZE),
				url: S(pullRequest.userAvatarUrl))
			if faded { userImage.alphaValue = DISABLED_FADE }
			addSubview(userImage)
			shift = AVATAR_PADDING+AVATAR_SIZE
		} else {
			shift = -4
		}
		pinRect = NSOffsetRect(pinRect, shift, 0)
		dateRect = NSOffsetRect(dateRect, shift, 0)
		titleRect = NSOffsetRect(titleRect, shift, 0)
		var replacementRects = [NSValue]()
		for rv in statusRects {
			replacementRects.append(NSValue(rect: CGRectOffset(rv.rectValue, shift, 0)))
		}
		statusRects = replacementRects

		if showUnpin {
			if (pullRequest.condition?.integerValue ?? 0)==ItemCondition.Open.rawValue {
				let unmergeableLabel = CenterTextField(frame: pinRect)
				unmergeableLabel.textColor = NSColor.redColor()
				unmergeableLabel.font = NSFont(name: "Menlo-Regular", size: 8.0)
				unmergeableLabel.alignment = .Center
				unmergeableLabel.stringValue = "Cannot be merged"
				addSubview(unmergeableLabel)
			}
			else
			{
				let unpin = NSButton(frame: pinRect)
				unpin.title = "Remove"
				unpin.target = self
				unpin.action = #selector(TrailerCell.unPinSelected)
				unpin.setButtonType(NSButtonType.MomentaryLightButton)
				unpin.bezelStyle = NSBezelStyle.RoundRectBezelStyle
				unpin.font = NSFont.systemFontOfSize(10.0)
				addSubview(unpin)
			}
		}

		title = CenterTextField(frame: titleRect)
		title.attributedStringValue = _title
		addSubview(title)

		let subtitle = CenterTextField(frame: dateRect)
		subtitle.attributedStringValue = _subtitle
		addSubview(subtitle)

		if faded {
			title.alphaValue = DISABLED_FADE
			subtitle.alphaValue = DISABLED_FADE
		}

		if let s = statuses {
			for count in 0 ..< statusRects.count {
				let frame = statusRects[statusRects.count-count-1].rectValue
				let statusLabel = LinkField(frame: frame)
				let status = s[count]

				statusLabel.targetUrl = status.targetUrl
				statusLabel.needsCommand = !Settings.makeStatusItemsSelectable
				statusLabel.attributedStringValue = NSAttributedString(string: status.displayText, attributes: statusAttributes)
				statusLabel.textColor = status.colorForDisplay
				if faded {
					statusLabel.alphaValue = DISABLED_FADE
				}
				addSubview(statusLabel)
			}
		}

		updateMenu()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
