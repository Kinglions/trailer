
import CoreData

struct CacheUnit {
	let data: NSData
	let code: Int
	let etag: String
	let headers: NSData
	let lastFetched: NSDate

	func actualHeaders() -> [NSObject : AnyObject] {
		return NSKeyedUnarchiver.unarchiveObjectWithData(headers) as! [NSObject : AnyObject]
	}

	func parsedData() -> AnyObject? {
		return try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
	}
}

final class CacheEntry: NSManagedObject {

	@NSManaged var etag: String
	@NSManaged var code: NSNumber
	@NSManaged var data: NSData
	@NSManaged var lastTouched: NSDate
	@NSManaged var lastFetched: NSDate
	@NSManaged var key: String
	@NSManaged var headers: NSData

	func cacheUnit() -> CacheUnit {
		return CacheUnit(data: data, code: code.integerValue, etag: etag, headers: headers, lastFetched: lastFetched)
	}

	class func setEntry(key: String, code: Int, etag: String, data: NSData, headers: [NSObject : AnyObject]) {
		var e = entryForKey(key)
		if e == nil {
			e = NSEntityDescription.insertNewObjectForEntityForName("CacheEntry", inManagedObjectContext: mainObjectContext) as? CacheEntry
			e!.key = key
		}
		e!.code = code
		e!.data = data
		e!.etag = etag
		e!.headers = NSKeyedArchiver.archivedDataWithRootObject(headers)
		e!.lastFetched = NSDate()
		e!.lastTouched = NSDate()
	}

	class func entryForKey(key: String) -> CacheEntry? {
		let f = NSFetchRequest(entityName: "CacheEntry")
		f.fetchLimit = 1
		f.predicate = NSPredicate(format: "key == %@", key)
		f.returnsObjectsAsFaults = false
		if let e = try! mainObjectContext.executeFetchRequest(f).first as? CacheEntry {
			e.lastTouched = NSDate()
			return e
		} else {
			return nil
		}
	}

	class func cleanOldEntriesInMoc(moc: NSManagedObjectContext) {
		let f = NSFetchRequest(entityName: "CacheEntry")
		f.returnsObjectsAsFaults = true
		f.predicate = NSPredicate(format: "lastTouched < %@", NSDate().dateByAddingTimeInterval(-3600.0*24.0*7.0)) // week-old
		for e in try! moc.executeFetchRequest(f) as! [CacheEntry] {
			DLog("Expiring unused cache entry for key %@", e.key)
			moc.deleteObject(e)
		}
	}

	class func markKeyAsFetched(key: String) {
		if let e = entryForKey(key) {
			e.lastFetched = NSDate()
		}
	}
}
