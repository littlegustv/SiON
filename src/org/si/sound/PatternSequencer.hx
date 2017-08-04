//----------------------------------------------------------------------------------------------------
// Pattern sequencer class
//  Copyright (c) 2009 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------


package org.si.sound;

import org.si.sion.*;
import org.si.sion.sequencer.base.*;
import org.si.sion.sequencer.SiMMLTrack;
import org.si.sound.patterns.*;

import org.si.sound.synthesizers.*;


/** Pattern sequencer class provides simple one track pattern player. The sequence pattern is represented as Vector.&lt;Note&gt;.
@see org.si.sound.patterns.Note 
@example Simple usage
<listing version="3.0">
// create new instance
var ps:PatternSequencer = new PatternSequencer();

// set sequence pattern by Note vector
var pat:Vector.&lt;Note&gt; = new Vector.&lt;Note&gt;();
pat.push(new Note(60, 64, 1));  // note C
pat.push(new Note(62, 64, 1));  // note D
pat.push(new Note(64, 64, 2));  // note E with length of 2
pat.push(null);                 // rest; null means no operation
pat.push(new Note(62, 64, 2));  // note D with length of 2
pat.push(new Note().setRest()); // rest; Note.setRest() method set no operation

// PatternSequencer.sequencer is the sound player
ps.sequencer.pattern = pat;

// play sequence "l16 $cde8d8" in MML
ps.play();
</listing>
 */
class PatternSequencer extends SoundObject
{
    public var sequencer(get, never) : Sequencer;
    public var portament(get, set) : Int;
    public var onEnterFrame(get, set) : Sequencer->Void;
    public var onEnterSegment(get, set) : Sequencer->Void;
    public var onExitFrame(get, set) : Sequencer->Void;

    // variables
    //----------------------------------------
    /** @private [protected] Sequencer instance */
    private var _sequencer : Sequencer;
    /** @private [protected] Sequence data */
    private var _data : SiONData;
    
    /** @private [protected] */
    private var _callbackEnterFrame : Sequencer->Void = null;
    /** @private [protected] */
    private var _callbackEnterSegment : Sequencer->Void = null;
    
    
    
    
    // properties
    //----------------------------------------
    /** the Sequencer instance belonging to this PatternSequencer, where the sequence pattern appears. */
    private function get_sequencer() : Sequencer{return _sequencer;
    }
    
    
    /** portament */
    private function get_portament() : Int {
        return _sequencer.portament;
    }
    private function set_portament(p : Int) : Int {
        _sequencer.setPortament(p);
        return p;
    }
    
    /** current note in the sequence, you cannot change this property. */
    override private function get_note() : Int{return _sequencer.note;
    }
    override private function set_note(n : Int) : Int{_errorCannotChange("note");
        return n;
    }
    
    /** current length in the sequence, you cannot change this property. */
    override private function get_length() : Float{return _sequencer.length;
    }
    override private function set_length(l : Float) : Float{_errorCannotChange("length");
        return l;
    }
    
    /** current length in the sequence, you cannot change this property. */
    override private function set_gateTime(g : Float) : Float{
        _sequencer.defaultGateTime = _gateTime = ((g < 0)) ? 0 : ((g > 1)) ? 1 : g;
        return g;
    }
    
    
    /** callback on enter frame */
    private function get_onEnterFrame() : Sequencer->Void {
        return _callbackEnterFrame;
    }
    private function set_onEnterFrame(f : Sequencer->Void) : Sequencer->Void {
        _callbackEnterFrame = f;
        return f;
    }
    
    /** callback on enter segment */
    private function get_onEnterSegment() : Sequencer->Void {
        return _callbackEnterSegment;
    }
    private function set_onEnterSegment(f : Sequencer->Void) : Sequencer->Void {
        _callbackEnterSegment = f;
        return f;
    }
    
    /** callback on exit frame */
    private function get_onExitFrame() : Sequencer->Void {
        return _sequencer.onExitFrame;
    }
    private function set_onExitFrame(f : Sequencer->Void) : Sequencer->Void {
        _sequencer.onExitFrame = f;
        return f;
    }
    
    
    
    
    // constructor
    //----------------------------------------
    /** constructor 
     *  @param defaultNote Default note, this value is referenced when Note.note property is -1.
     *  @param defaultVelocity Default velocity, this value is referenced when Note.velocity property is -1.
     *  @param defaultLength Default length, this value is referenced when Note.length property is Number.NaN.
     *  @param synth synthesizer to play
     */
    public function new(defaultNote : Int = 60, defaultVelocity : Int = 128, defaultLength : Int = 0, synth : VoiceReference = null)
    {
        super("PatternSequencer", synth);
        _data = new SiONData();
        _sequencer = new Sequencer(this, _data, defaultNote, defaultVelocity, defaultLength);
        _sequencer.onEnterFrame = _onEnterFrame;
        _sequencer.onEnterSegment = _onEnterSegment;
    }
    
    
    
    
    // operations
    //----------------------------------------
    /** start sequence */
    override public function play() : Void
    {
        stop();
        var list : Array<SiMMLTrack> = _sequenceOn(_data, false, false);
        if (list.length > 0) {
            _track = _sequencer.play(list[0]);
            _synthesizer._registerTrack(_track);
        }
    }
    
    
    /** stop sequence */
    override public function stop() : Void
    {
        if (_track != null) {
            _sequencer.stop();
            _synthesizer._unregisterTracks(_track);
            _track.setDisposable();
            _track = null;
            _sequenceOff(true);
        }
        _stopEffect();
    }
    
    
    
    
    // internal
    //----------------------------------------
    /** @private [protected] handler on enter segment */
    override private function _onEnterFrame(seq : Sequencer) : Void
    {
        if (_callbackEnterFrame != null) _callbackEnterFrame(seq);
        super._onEnterFrame(seq);
    }
    
    
    /** @private [protected] handler on enter segment */
    override private function _onEnterSegment(seq : Sequencer) : Void
    {
        if (_callbackEnterSegment != null) _callbackEnterSegment(seq);
        super._onEnterSegment(seq);
    }
}


