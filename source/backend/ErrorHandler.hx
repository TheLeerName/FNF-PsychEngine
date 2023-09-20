package backend;

import flixel.FlxState;
import sys.thread.Thread;
import lime.app.Application;
import flixel.math.FlxPoint;

/**
 * State with error logging of some code
 * @author TheLeerName
 */
@:access(flixel.FlxCamera)
@:cppInclude('windows.h')
class ErrorHandler extends FlxState {
	public static function setStuff(title:String, content:String, ?errorLines:Array<String>) {
		FlxG.save.data.options_errorHandler = {
			title: title,
			content: content,
			errorLines: errorLines
		};
		FlxG.save.flush();
	}

	var text:FlxText;

	var title:String = "ERROR";
	var content:String = "Unexpected error";
	var errorLines:Array<String> = [];

	var scrollX(default, set):Float;
	var scrollY(default, set):Float;

	override function create() {
		var time = Sys.time();

		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.mouse.useSystemCursor = true;
		FlxG.stage.color = 0xffffff;
		FlxG.camera.bgColor = 0;
		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		FlxG.scaleMode = new flixel.system.scaleModes.StageSizeScaleMode();

		title = FlxG.save.data.options_errorHandler.title;
		content = FlxG.save.data.options_errorHandler.content;
		errorLines = FlxG.save.data.options_errorHandler.errorLines;

		content = content.replace('\r\n', '\n');
		errorLines = mergeDuplicates(errorLines);

		super.create();

		text = new FlxText(10, 0, 0, content);
		text.setFormat('_sans', 14, 0xff000000);
		add(text);

		var lineHeight:Float = text.height / text.textField.numLines - 0.02;
		for (line in errorLines) {
			if (!line.contains(':')) continue;
			var index:Int = Std.parseInt(line.substring(0, line.indexOf(':')).trim());
			var txt:String = line.substring(line.indexOf(':') + 1).trim();
			trace(index, txt);
			add(new ErrorInfo(0, lineHeight * (index - 1), txt));
		}

		// removes window icon and buttons
		#if windows
		untyped __cpp__('
			HWND hwnd = GetActiveWindow();
			SetWindowLongPtr(hwnd, GWL_STYLE, GetWindowLongPtr(hwnd, GWL_STYLE) & ~WS_SYSMENU);
		');
		#end

		var bounds = {x: getWidth(text.width), y: getHeight(text.height)};
		Application.current.window.resize(bounds.x, bounds.y);
		screenCenter();
		Application.current.window.title = title;

		trace(Math.floor((Sys.time() - time) * 1000) + 'ms elapsed');
	}

	function screenCenter() {
		Application.current.window.move(
			Std.int((Application.current.window.display.bounds.width - Application.current.window.width) / 2),
			Std.int((Application.current.window.display.bounds.height - Application.current.window.height) / 2)
		);
	}

	function getWidth(width:Float):Int {
		var displayWidth:Float = Application.current.window.display.bounds.width;
		width = Math.max(displayWidth / 8, width);
		width = Math.min(displayWidth / 1.25, width);
		return Std.int(width);
	}

	function getHeight(height:Float):Int {
		var displayHeight:Float = Application.current.window.display.bounds.height;
		height = Math.max(displayHeight / 8, height);
		height = Math.min(displayHeight / 1.25, height);
		return Std.int(height);
	}

	function mergeDuplicates(errorLines:Array<String>) {
		// if errors on same line, merge it
		var lastLines:String = "69:mondayleftmebroken";
		var newArray:Array<String> = [];
		for (err in errorLines) {
			if (err.substring(0, err.indexOf(':')).trim() == lastLines.substring(0, lastLines.indexOf(':')).trim())
				newArray[newArray.length - 1] += '; ' + err.substring(err.indexOf(':') + 1).trim();
			else
				newArray.push(err);
			lastLines = err;
		}
		return newArray;
	}

	inline function set_scrollX(v:Float):Float {
		if (text.width > FlxG.width) {
			v = Math.min(v, text.width - FlxG.width);
			v = Math.max(v, 0);
			return scrollX = FlxG.camera.scroll.x = v;
		}
		return scrollX;
	}
	inline function set_scrollY(v:Float):Float {
		if (text.height > FlxG.height) {
			v = Math.min(v, text.height - FlxG.height);
			v = Math.max(v, 0);
			return scrollY = FlxG.camera.scroll.y = v;
		}
		return scrollY;
	}

	var mousePos:FlxPoint = FlxPoint.get();
	var initPos:FlxPoint = FlxPoint.get();
	var timeToUnshow:Float = 0;
	override function update(elapsed:Float) {
		if (FlxG.mouse.justPressed) {
			mousePos = FlxG.mouse.getScreenPosition();
			initPos = FlxG.camera.scroll.clone();
		}
		if (FlxG.mouse.pressed) {
			scrollX = initPos.x - (FlxG.mouse.screenX - mousePos.x) * 2;
			scrollY = initPos.y - (FlxG.mouse.screenY - mousePos.y) * 2;
		}

		if (FlxG.mouse.justPressedRight || (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C)) {
			lime.system.Clipboard.text = content;

			Application.current.window.title = title + ' | Copied!';
			timeToUnshow = 2;
		}

		if (timeToUnshow > 0)
			timeToUnshow = Math.max(0, timeToUnshow - elapsed);
		else
			Application.current.window.title = title + ' | Copy error by RMB or Ctrl + C';

		if (FlxG.mouse.wheel != 0) {
			if (FlxG.keys.pressed.SHIFT)
				scrollX -= FlxG.mouse.wheel * 100;
			else
				scrollY -= FlxG.mouse.wheel * 100;
		}

		if (Controls.instance.ACCEPT)
			Application.current.window.close();

		super.update(elapsed);
	}
}

class ErrorInfo extends FlxSpriteGroup {
	public var bg:FlxSprite;
	public var text:FlxText;

	var __width:Int = 10;

	public function new(x:Float, y:Float, content:String) {
		super(x, y);

		bg = new FlxSprite(0, 0).makeGraphic(1, 1, 0xffff0000);
		add(bg);

		text = new FlxText(__width);
		text.text = content;
		text.setFormat('_sans', 14, 0xffffffff);
		add(text);

		bg.scale.set(__width, text.height);
		bg.updateHitbox();
	}

	override function update(elapsed:Float) {
		if (FlxG.mouse.overlaps(this) && !text.visible) {
			bg.scale.set(text.width + __width, text.height);
			bg.updateHitbox();

			text.visible = true;
		}
		if (!FlxG.mouse.overlaps(this) && text.visible) {
			bg.scale.set(__width, text.height);
			bg.updateHitbox();

			text.visible = false;
		}

		super.update(elapsed);
	}
}