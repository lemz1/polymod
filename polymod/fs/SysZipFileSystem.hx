package polymod.fs;

import polymod.fs.ZipFileSystem.ZipFileSystemParams;

#if !sys
class SysZipFileSystem extends polymod.fs.StubFileSystem
{
	public function new(params:ZipFileSystemParams)
	{
		super(params);
		Polymod.warning(FUNCTIONALITY_NOT_IMPLEMENTED, "This file system not supported for this platform, and is only intended for use on sys targets");
	}
}
#else
import haxe.io.Bytes;
import haxe.io.Path;
import polymod.Polymod.ModMetadata;
import polymod.util.Util;
import polymod.util.zip.ZipParser;
import sys.io.File;
import thx.semver.VersionRule;

using StringTools;

/**
 * An implementation of an IFileSystem that can access files from an un-compressed zip archive.
 * This file system pretends as though the files in the ZIPs are in the mod root;
 * this allows both zips and folders to be enabled as mods.
 * Useful for loading mods from zip files.
 * Compatible only with native targets. Currently does not support compressed zip files.
 */
class SysZipFileSystem extends SysFileSystem
{
	/**
	 * Specifies the name of the ZIP that contains each file.
	 */
	var filesLocations:Map<String, String>;

	/**
	 * Specifies the names of available directories within the ZIP files.
	 */
	var fileDirectories:Array<String>;

	/**
	 * The wrappers for each ZIP file that is loaded.
	 */
	var zipParsers:Map<String, ZipParser>;

	public function new(params:ZipFileSystemParams)
	{
		super(params);
		filesLocations = new Map<String, String>();
		zipParsers = new Map<String, ZipParser>();
		fileDirectories = [];
	}

	/**
	 * Retrieve file bytes by pulling them from the ZIP file.
	 */
	public override function getFileBytes(path:String):Null<Bytes>
	{
		if (!filesLocations.exists(path))
		{
			// Fallback to the inner SysFileSystem.
			return super.getFileBytes(path);
		}
		else
		{
			// Rather than going to the `files` map for the contents (which are empty),
			// we go directly to the zip file and extract the individual file.
			var zipParser = zipParsers.get(filesLocations.get(path));

			var innerPath = path;
			if (innerPath.startsWith(modRoot)) {
				innerPath = innerPath.substring(
					modRoot.endsWith("/") ? modRoot.length : modRoot.length + 1
				);
			}

			var fileHeader = zipParser.getLocalFileHeaderOf(innerPath);
			if (fileHeader == null) {
				// Couldn't access file
				trace('WARNING: Could not access file $innerPath from ZIP ${zipParser.fileName}.');
				return null;
			}
			var fileBytes = fileHeader.readData();
			return fileBytes;
		}
	}

	public override function exists(path:String) {
		if (filesLocations.exists(path))
			return true;
		if (fileDirectories.contains(path))
			return true;
		
		return super.exists(path);
	}
	
	public override function isDirectory(path:String) {
		if (fileDirectories.contains(path))
			return true;
		
		if (filesLocations.exists(path))
			return false;

		return super.isDirectory(path);
	}

	public override function readDirectory(path:String) {
		// Remove trailing slash
		if (path.endsWith("/"))
			path = path.substring(0, path.length - 1);

		var result = super.readDirectory(path);

		if (fileDirectories.contains(path)) {
			// We check if directory ==, because
			// we don't want to read the directory recursively.

			for (file in filesLocations.keys()) {
				if (Path.directory(file) == path) {
					result.push(Path.withoutDirectory(file));
				}
			}
			for (dir in fileDirectories) {
				if (Path.directory(dir) == path) {
					result.push(Path.withoutDirectory(dir));
				}
			}
		}

		return result;
	}

	/**
	 * Scan the mod root for ZIP files and add each one to the SysZipFileSystem.
	 */
	public function addAllZips():Void {
		trace('Searching for ZIP files in ' + modRoot);
		// Use SUPER because we don't want to add in files within the ZIPs.
		var modRootContents = super.readDirectory(modRoot);
		trace('Found ' + modRootContents.length + ' files');


		for (modRootFile in modRootContents) {
			var filePath = Util.pathJoin(modRoot, modRootFile);

			if (isDirectory(filePath))
				continue;

			if (StringTools.endsWith(filePath, ".zip")) {
				trace('- Found zip file' + filePath);
				addZipFile(filePath);
			}
		}
	}

	public function addZipFile(zipPath:String)
	{
		var zipParser = new ZipParser(zipPath);

		// SysZipFileSystem doesn't actually use the internal `files` map.
		// We populate it here simply so we know the files are there.
		for (fileName => fileHeader in zipParser.centralDirectoryRecords)
		{
			if (fileHeader.compressedSize != 0 && fileHeader.uncompressedSize != 0 && !StringTools.endsWith(fileHeader.fileName, '/'))
			{
				// Add to the list of files.
				var fullFilePath = Util.pathJoin(modRoot, fileHeader.fileName);
				filesLocations.set(fullFilePath, zipPath);
				
				// Generate the list of directories.
				var fileDirectory = Path.directory(fullFilePath);
				// Resolving recursively ensures parent directories are registered.
				// If the directory is already registered, its parents are already registered as well.
				while (fileDirectory != "" && !fileDirectories.contains(fileDirectory)) {
					fileDirectories.push(fileDirectory);
					fileDirectory = Path.directory(fileDirectory);
				}
			}
		}
		
		// Store the ZIP parser for later use.
		zipParsers.set(zipPath, zipParser);
	}
}
#end
