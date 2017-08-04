package;

import openfl.ui.Keyboard;
import openfl.Lib;
import siONTenorion.Tenorion;
import tutorials.TheABCSong;
import tutorials.EventTrigger;
import tutorials.SoundFontSample;
import tutorials.CustomFader;
import tutorials.NomlMusic;
import siONKaosillator.Kaosillator;

import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.display.Sprite;
import openfl.text.TextField;

class Main extends Sprite
{
	public static inline var DEAD_ZONE : Float = 0.4;
	static inline public var BUTTON_SELECT : Int = 0;
	static inline public var BUTTON_BACK : Int = 9;

	var mMenu : Menu;
	var mCurrentDemo : Sprite = null;

	// constructor
	public function new() {
		super();
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		// TODO: GameInput
		//stage.addEventListener(JoystickEvent.BUTTON_DOWN, onJoyButtonDown);

		mMenu = new Menu(this);
		addChild(mMenu);
	}

	public function runSelection(classType : Class<Dynamic>) {
		removeChild(mMenu);
		mCurrentDemo = Type.createInstance( classType, [] );
		addChild(mCurrentDemo);
	}

	private function onKeyUp(event:KeyboardEvent) {
		if (event.keyCode == Keyboard.ESCAPE) { // BACK on Android
			event.stopImmediatePropagation ();
			if (mCurrentDemo == null) {
				// End the program
				//Lib.exit(); TODO: EXIT
			}
			else {
				// End the current demo, return to the main menu
				removeChild(mCurrentDemo);
				mCurrentDemo = null;
				addChild(mMenu);
			}
		}
	}

// TODO: GameInput
/*
	private function onJoyButtonDown (event:JoystickEvent):Void {
		if (event.id == Main.BUTTON_BACK) {
			trace('Button BACK hit');
			if (mCurrentDemo == null) {
				// End the program
				Lib.exit ();
			}
			else {
				// End the current demo, return to the main menu
				removeChild(mCurrentDemo);
				mCurrentDemo = null;
				addChild(mMenu);
			}
		}
	}
*/
}

class Menu extends Sprite
{
	private var mMain : Main = null;

	private static inline var menuTop : Int = 40;
	private static inline var menuLeft : Int = 50;
	private static inline var menuSpacing : Int = 70;
	private static inline var fontSize : Int = 48;

	private var menuItems = [
        { name: "NomlMusic", type: NomlMusic},
        { name: "ABC Song", type: TheABCSong},
        { name: "Event Trigger Test", type: EventTrigger},
        { name: "Kaosillator", type: Kaosillator},
        //{ name: "KaosPad", type: KaosPad},
        //{ name: "Keyboard", type: Keyboard},
        { name: "Tenorion", type: Tenorion},
		{ name: "Custom Fader", type: CustomFader},
		{ name: "Sound Font", type: SoundFontSample},
	];

	private var mSelector : TextField;

	private var mSelectedItem : Int = 0;

	// constructor
	public function new(main : Main)
	{
		super();
		mMain = main;
		addEventListener (Event.ADDED_TO_STAGE, onAddedToStage);
	}

	private var mInitialized : Bool = false;

	private function onAddedToStage (event:Event):Void {
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);

		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(TouchEvent.TOUCH_TAP, onTouchTap);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

		if (mInitialized) {
			mSelector.y = menuTop;
		}
		else {
			var ts = new openfl.text.TextFormat();
			ts.font = "Arial";  // set the font
			ts.size = fontSize; // set the font size
			ts.color=0x000000;  // set the color

			var menuY = menuTop;

			for (item in menuItems) {
				var text = new TextField();
				text.x = menuLeft;
				text.y = menuY;
				text.width = 600;
				text.height = menuSpacing;
				text.text = item.name;
				text.setTextFormat(ts);
				addChild(text);

				menuY += menuSpacing;
			}

			mSelector = new TextField();
			mSelector.x = menuLeft - 30;
			mSelector.y = menuTop;
			mSelector.width = 32;
			mSelector.height = menuSpacing;
			mSelector.text = ">";
			mSelector.setTextFormat(ts);
			addChild(mSelector);

			mInitialized = true;
		}
	}

	private function onRemovedFromStage (event:Event):Void {
		addEventListener (Event.ADDED_TO_STAGE, onAddedToStage);
	}

	private function onTouchTap(event:TouchEvent) {
		trace('********** TouchTap: $event');
		trace('Local: ${event.localX}, ${event.localY}');
		trace('Stage: ${event.stageX}, ${event.stageY}');
		trace('Delta: ${event.delta}');
		trace('Location of stage: ${stage.x}, ${stage.y}');
		runAt(Math.round(event.localX), Math.round(event.localY));
	}

	private function onMouseDown(event:MouseEvent) {
		runAt(Math.round(mouseX), Math.round(mouseY));
	}

	private function updateSelector() {
		mSelector.y = menuTop + mSelectedItem * menuSpacing;
	}

	private function runAt(x : Int, y : Int) {
		var selection = Std.int((y - menuTop) / menuSpacing);
		if (selection < 0 || selection > menuItems.length - 1) return;

		mSelectedItem = selection;
		runSelection();
	}

	private function menuUp() {
		if (mSelectedItem > 0) {
			mSelectedItem--;
		}
		updateSelector();
	}

	private function menuDown() {
		if (mSelectedItem < menuItems.length - 1) {
			mSelectedItem++;
		}
		updateSelector();
	}

	private function runSelection() {
		trace('Running ${menuItems[mSelectedItem].name}');

		stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.removeEventListener(TouchEvent.TOUCH_TAP, onTouchTap);
		stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

		mMain.runSelection( menuItems[mSelectedItem].type );
	}

	private function onKeyDown(event:KeyboardEvent) {
		switch (event.keyCode) {
		case 40: // arrow down
			menuDown();

		case 38: // arrow up
			menuUp();

		case 13: // return
			runSelection();
		}
	}
}
