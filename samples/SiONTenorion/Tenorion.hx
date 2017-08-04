// SiON TENORION

package siONTenorion;

import openfl.display.Sprite;
import openfl.events.*;
import openfl.text.TextField;
import org.si.sion.*;
import org.si.sion.events.*;
import org.si.sion.utils.SiONPresetVoice;
import openfl.display.*;
import openfl.geom.*;

class Tenorion extends Sprite
{
    // driver
    public var driver : SiONDriver = new SiONDriver();
    
    // preset voice
    public var presetVoice : SiONPresetVoice = new SiONPresetVoice();
    
    // voices, notes and tracks
    public var voices : Array<SiONVoice> = new Array<SiONVoice>();
    public var notes : Array<Int> = [36, 48, 60, 72, 43, 48, 55, 60, 65, 67, 70, 72, 77, 79, 82, 84];
    public var length : Array<Int> = [1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 4, 4, 4, 4, 4, 4];
    
    // beat counter
    public var beatCounter : Int;
    
    // control pad
    public var matrixPad : MatrixPad;
    
    // constructor
    public function new()
    {
        super();
        driver.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        driver.addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
        addChild(driver);
    }

    private function onAddedToStage (event:Event):Void {
        var i : Int;
        
        // set voices from preset
        voices[0] = presetVoice.voices.get("valsound.percus1");  // bass drum
        voices[1] = presetVoice.voices.get("valsound.percus28");  // snare drum
        voices[2] = presetVoice.voices.get("valsound.percus17");  // close hihat
        voices[3] = presetVoice.voices.get("valsound.percus23");  // open hihat
        for (i in 4...8 ) voices[i] = presetVoice.voices.get("valsound.bass18"); // others

        // listen
        driver.setBeatCallbackInterval(1);
        driver.addEventListener(SiONTrackEvent.BEAT, _onBeat);
        driver.setTimerInterruption(1, _onTimerInterruption);
        
        // control pad
        matrixPad = new MatrixPad(stage);
        addChild(matrixPad);
        
        // start streaming
        beatCounter = 0;
        driver.play();
    }

    private function onRemovedFromStage (event:Event):Void {
        driver.stop();
    }

    // _onBeat (SiONTrackEvent.BEAT) is called back in each beat at the sound timing.
    private function _onBeat(e : SiONTrackEvent) : Void
    {
        matrixPad.beat(e.eventTriggerID & 15);
    }
    
    
    // _onTimerInterruption (SiONDriver.setTimerInterruption) is called back in each beat at the buffering timing.
    private function _onTimerInterruption() : Void
    {
        var beatIndex : Int = beatCounter & 15;
        for (i in 0...16) {
            //trace('Turning on ${matrixPad.sequences[i]}');
            if (matrixPad.sequences[i] & (1 << beatIndex) != 0) {
                driver.noteOn(notes[i], voices[i], length[i]);
            }
        }
        beatCounter++;
    }
}


class MatrixPad extends Bitmap
{
    public var sequences : Array<Int> = new Array<Int>();
    private var canvas : Shape = new Shape();
    private var buffer : BitmapData;
    private var padOn : BitmapData;
    private var padOff : BitmapData;
    private var pt : Point = new Point();
    private var colt : ColorTransform = new ColorTransform(1, 1, 1, 0.1);
    private var padWidth : Int;
    private var padHeight : Int;
    private var joyBeat : Int = -1;
    private var joyTrack : Int = -1;

    public function new(stage : Stage)
    {
        super(new BitmapData(stage.stageWidth, stage.stageHeight, false, 0));
        buffer = new BitmapData(stage.stageWidth, stage.stageHeight, true, 0);
        padWidth = Std.int(stage.stageWidth / 16);
        padHeight = Std.int(stage.stageHeight / 16);
        padOn = _pad(0x303050, 0x6060a0);
        padOff = _pad(0x303050, 0x202040);
        var i : Int;
        for (i in 0...256) {
            pt.x = Std.int((i & 0x0F) * padWidth);
            pt.y = Std.int((i & 0xF0) * padHeight / 16);
            buffer.copyPixels(padOff, padOff.rect, pt);
            bitmapData.copyPixels(padOff, padOff.rect, pt);
        }
        for (i in 0...16) {
            sequences[i] = 0;
        }
        stage.addEventListener(Event.REMOVED_FROM_STAGE, _onRemoved);
        addEventListener("enterFrame", _onEnterFrame);
        stage.addEventListener("click", _onClick);
    }

    private var bJustMoved : Bool = false;

    private function beatRight() {
        if (joyBeat == -1 || joyTrack == -1) {
            joyBeat = 0;
            joyTrack = 0;
            return;
        }

        if (joyBeat < 15) {
            joyBeat++;
        }
    }

    private function beatLeft() {
        if (joyBeat == -1 || joyTrack == -1) {
            joyBeat = 0;
            joyTrack = 0;
            return;
        }

        joyBeat--;
    }

    private function trackDown() {
        if (joyBeat == -1 || joyTrack == -1) {
            joyBeat = 0;
            joyTrack = 0;
            return;
        }

        if (joyTrack < 15) {
            joyTrack++;
        }
    }

    private function trackUp() {
        if (joyBeat == -1 || joyTrack == -1) {
            joyBeat = 0;
            joyTrack = 0;
            return;
        }

        joyTrack--;
    }

// TODO: GameInput
/*
    private function onJoyAxisMove (event:JoystickEvent):Void {
        if (Math.abs(event.x) < Main.DEAD_ZONE && Math.abs(event.y) < Main.DEAD_ZONE) {
            bJustMoved = false;
            return;
        }

        if (bJustMoved) return;

        if (event.x < -Main.DEAD_ZONE) {
            bJustMoved = true;
            beatLeft();
        }
        else if (event.x > Main.DEAD_ZONE) {
            bJustMoved = true;
            beatRight();
        }

        if (event.y < -Main.DEAD_ZONE) {
            bJustMoved = true;
            trackUp();
        }
        else if (event.y > Main.DEAD_ZONE) {
            bJustMoved = true;
            trackDown();
        }
    }

    private function onJoyButtonDown (event:JoystickEvent):Void {
        trace('Joy button down ${event.id}');
        if (event.id == Main.BUTTON_SELECT) {
            sequences[15-joyTrack] ^= 1 << joyBeat;
            pt.x = Std.int(joyBeat * padWidth);
            pt.y = Std.int(joyTrack * padHeight);
            if (sequences[15-joyTrack] & (1 << joyBeat) != 0) buffer.copyPixels(padOn, padOn.rect, pt)
            else buffer.copyPixels(padOff, padOff.rect, pt);
        }
    }
*/

    private function _onRemoved(e: Event) {
        removeEventListener("enterFrame", _onEnterFrame);
        stage.removeEventListener("click", _onClick);
    }

    private function _pad(border : Int, face : Int) : BitmapData {
        var pix : BitmapData = new BitmapData(padWidth, padHeight, false, 0);
        canvas.graphics.clear();
        canvas.graphics.lineStyle(1, border);
        canvas.graphics.beginFill(face);
        canvas.graphics.drawRect(1, 1, padWidth - 3, padHeight - 3);
        canvas.graphics.endFill();
        pix.draw(canvas);
        return pix;
    }
    
    
    private function _onEnterFrame(e : Event) : Void{
        bitmapData.draw(buffer, null, colt);
        var bitmapSelection : BitmapData = new BitmapData(padWidth, padHeight, true, 0);
        var selection : Shape = new Shape();
        selection.graphics.clear();
        selection.graphics.lineStyle(1, 0xFF0000);
        selection.graphics.beginFill(0xFF0000, 0.0);
        selection.graphics.drawRect(1, 1, padWidth - 3, padHeight - 3);
        selection.graphics.endFill();
        bitmapSelection.draw(selection);
        pt.x = joyBeat * padWidth;
        pt.y = joyTrack * padHeight;
        bitmapData.copyPixels(bitmapSelection, bitmapSelection.rect, pt, null, null, true);
    }
    
    
    private function _onClick(e : Event) : Void{
        if (mouseX >= 0 && mouseX < stage.stageWidth && mouseY >= 0 && mouseY < stage.stageHeight) {
            var track : Int = 15 - Math.floor(mouseY / padHeight);
            var beat : Int = Math.floor(mouseX / padWidth);
            sequences[track] ^= 1 << beat;
            pt.x = Std.int(beat * padWidth);
            pt.y = Std.int((15 - track) * padHeight);
            if (sequences[track] & (1 << beat) != 0) buffer.copyPixels(padOn, padOn.rect, pt)
            else buffer.copyPixels(padOff, padOff.rect, pt);
        }
    }
    
    
    public function beat(beat16th : Int) : Void{
        pt.x = beat16th * padWidth;
        pt.y = 0;
        while (pt.y < 16 * padHeight) {
            bitmapData.copyPixels(padOn, padOn.rect, pt);
            pt.y += padHeight;
        }
    }
}
