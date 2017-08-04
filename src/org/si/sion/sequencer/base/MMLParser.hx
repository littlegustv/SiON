//----------------------------------------------------------------------------------------------------
// MML parser class
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.sequencer.base;

import openfl.utils.Timer;
import openfl.errors.Error;

/** MML parser class. */
class MMLParser
{
    public static var keySign(never, set) : String;
    public static var parseProgress(get, never) : Float;

    // tables
    //--------------------------------------------------
    private static var _keySignatureTable : Array<Dynamic> = [
        [0, 0, 0, 0, 0, 0, 0], 
        [0, 0, 0, 1, 0, 0, 0], 
        [1, 0, 0, 1, 0, 0, 0], 
        [1, 0, 0, 1, 1, 0, 0], 
        [1, 1, 0, 1, 1, 0, 0], 
        [1, 1, 0, 1, 1, 1, 0], 
        [1, 1, 1, 1, 1, 1, 0], 
        [1, 1, 1, 1, 1, 1, 1], 
        [0, 0, 0, 0, 0, 0, -1], 
        [0, 0, -1, 0, 0, 0, -1], 
        [0, 0, -1, 0, 0, -1, -1], 
        [0, -1, -1, 0, 0, -1, -1], 
        [0, -1, -1, 0, -1, -1, -1], 
        [-1, -1, -1, 0, -1, -1, -1], 
        [-1, -1, -1, -1, -1, -1, -1]];


    public static inline var INT_MIN_VALUE = -2147483648;

    
    // variables
    //--------------------------------------------------
    // settting
    private static var _setting : MMLParserSetting = null;
    
    // MML string
    private static var _mmlString : String = null;
    
    // user defined event map.
    private static var _userDefinedEventID : Map<String,Int> = null;
    
    // system event strings
    private static var _systemEventStrings : Array<String> = new Array<String>();
    private static var _sequenceMMLStrings : Array<String> = new Array<String>();
    
    // flag list of global event
    private static var _globalEventFlags : Array<Bool> = null;
    
    // temporaries
    private static var _freeEventChain : MMLEvent = null;
    
    private static var _interruptInterval : Int = 0;
    private static var _startTime : Int = 0;
    private static var _parsingTime : Int = 0;
    
    private static var _staticLength : Int = 0;
    private static var _staticOctave : Int = 0;
    private static var _staticNoteShift : Int = 0;
    private static var _isLastEventLength : Bool = false;
    private static var _systemEventIndex : Int = 0;
    private static var _sequenceMMLIndex : Int = 0;
    private static var _headMMLIndex : Int = 0;
    private static var _cacheMMLString : Bool = false;
    
    private static var _keyScale : Array<Int> = [0, 2, 4, 5, 7, 9, 11];
    private static var _keySignature : Array<Int> = _keySignatureTable[0];
    private static var _keySignatureCustom : Array<Int> = new Array<Int>();
    private static var _terminator : MMLEvent = new MMLEvent();
    private static var _lastEvent : MMLEvent = null;
    private static var _lastSequenceHead : MMLEvent = null;
    private static var _repeatStac : Array<Dynamic> = [];
    
    
    
    
    // properties
    //--------------------------------------------------
    /** Key signature for all notes. The letter for key signature is expressed as /[A-G][+\-#b]?m?/. */
    private static function set_keySign(sign : String) : String
    {
        var note : Int;
        var i : Int;
        var list : Array<Dynamic>;
        var shift : String;
        var noteLetters : String = "cdefgab";
        switch (sign)
        {
            case "", "C", "Am"           :_keySignature = _keySignatureTable[0];
            case "G", "Em"               :_keySignature = _keySignatureTable[1];
            case "D", "Bm"               :_keySignature = _keySignatureTable[2];
            case "A", "F+m", "F#m"       :_keySignature = _keySignatureTable[3];
            case "E", "C+m", "C#m"       :_keySignature = _keySignatureTable[4];
            case "B", "G+m", "G#m"       :_keySignature = _keySignatureTable[5];
            case "F+", "F#", "D+m", "D#m":_keySignature = _keySignatureTable[6];
            case "C+", "C#", "A+m", "A#m":_keySignature = _keySignatureTable[7];
            case "F", "Dm"               :_keySignature = _keySignatureTable[8];
            case "B-", "Bb", "Gm"        :_keySignature = _keySignatureTable[9];
            case "E-", "Eb", "Cm"        :_keySignature = _keySignatureTable[10];
            case "A-", "Ab", "Fm"        :_keySignature = _keySignatureTable[11];
            case "D-", "Db", "B-m", "Bbm":_keySignature = _keySignatureTable[12];
            case "G-", "Gb", "E-m", "Ebm":_keySignature = _keySignatureTable[13];
            case "C-", "Cb", "A-m", "Abm":_keySignature = _keySignatureTable[14];

            default:
                for (i in 0...7) {
                    _keySignatureCustom[i] = 0;
                }

                var compactRegex = new EReg("(\\s+,?\\s*|\\s*,\\s*)","gms");
                var compactString = compactRegex.replace(sign, ",");
                list = compactString.split(",");
                for (i in 0...list.length) {
                    note = noteLetters.indexOf(list[i].charAt(0).toLowerCase());
                    if (note == -1) throw errorKeySign(sign);
                    if (list.length > 1) {
                        shift = list[1].charAt(1);
                        _keySignatureCustom[note] = ((shift == "+" || shift == "#")) ? 1 : ((shift == "-" || shift == "b")) ? -1 : 0;
                    }
                    else {
                        _keySignatureCustom[note] = 0;
                    }
                }
                _keySignature = _keySignatureCustom;
        }
        return sign;
    }
    
    
    /** Parsing progression (0-1). */
    private static function get_parseProgress() : Float
    {
        if (_mmlString != null) {
            var lastPosition = _mmlRegExp.matchedPos();
            return lastPosition.pos / (_mmlString.length + 1);
        }
        return 0;
    }

    // constructor
    //--------------------------------------------------
    /** constructer do nothing. */
    public function new()
    {
    }
    

    // allocator
    //--------------------------------------------------
    /** @private [internal] Free all events in the sequence. */
    @:allow(org.si.sion.sequencer.base)
    private static function _freeAllEvents(seq : MMLSequence) : Void
    {
        if (seq.headEvent == null) return;

        // connect to free list
        seq.tailEvent.next = _freeEventChain;
        
        // update head of free list
        _freeEventChain = seq.headEvent;
        
        // clear
        seq.headEvent = null;
        seq.tailEvent = null;
    }
    
    
    /** @private [internal] Free event. */
    @:allow(org.si.sion.sequencer.base)
    private static function _freeEvent(e : MMLEvent) : MMLEvent
    {
        var next : MMLEvent = e.next;
        e.next = _freeEventChain;
        _freeEventChain = e;
        return next;
    }
    
    
    /** @private [internal] allocate event */
    @:allow(org.si.sion.sequencer.base)
    private static function _allocEvent(id : Int, data : Int, length : Int = 0) : MMLEvent
    {
        if (_freeEventChain != null) {
            var e : MMLEvent = _freeEventChain;
            _freeEventChain = _freeEventChain.next;
            return e.initialize(id, data, length);
        }
        return (new MMLEvent()).initialize(id, data, length);
    }
    
    
    
    
    // settting
    //--------------------------------------------------
    /** @private [internal] Set map of user defined ids. */
    @:allow(org.si.sion.sequencer.base)
    private static function _setUserDefinedEventID(map : Map<String, Int>) : Void
    {
        if (_userDefinedEventID != map) {
            _userDefinedEventID = map;
            _mmlRegExp = null;
        }
    }
    
    
    /** @private [internal] Set array of global event flags. */
    @:allow(org.si.sion.sequencer.base)
    private static function _setGlobalEventFlags(flags : Array<Bool>) : Void
    {
        _globalEventFlags = flags;
    }
    
    
    
    
    // public operation
    //--------------------------------------------------
    /* Add new event. */
    public static function addMMLEvent(id : Int, data : Int = 0, length : Int = 0, noteOption : Bool = false) : MMLEvent
    {
        trace('addMMLEvent($id, $data, $length, $noteOption)');
        if (!noteOption) {
            // Make channel data chain
            if (id == MMLEvent.SEQUENCE_HEAD) {
                _lastSequenceHead.jump = _lastEvent;
                _lastSequenceHead = _pushMMLEvent(id, data, length);
                _initialize_track();
            }
            else 
            // Concatinate REST event
            if (id == MMLEvent.REST && _lastEvent.id == MMLEvent.REST) {
                _lastEvent.length += length;
            }
            else {
                _pushMMLEvent(id, data, length);
                // seqHead.data is the count of global events
                if (_globalEventFlags[id])                     _lastSequenceHead.data++;
            }
        }
        else {
            // note option event is inserted after NOTE .
            if (_lastEvent.id == MMLEvent.NOTE) {
                length = _lastEvent.length;
                _lastEvent.length = 0;
                _pushMMLEvent(id, data, length);
            }
            else {
                // Error when there is no NOTE before SLUR event.
                throw errorSyntax("* or &");
            }
        }
        
        _isLastEventLength = false;
        return _lastEvent;
    }
    
    
    /** Get MMLEvent id by mml command letter. 
     *  @param mmlCommand letter of MML command.
     *  @return Event id. Returns 0 if not found.
     */
    public static function getEventID(mmlCommand : String) : Int
    {
        switch (mmlCommand)
        {case "c", "d", "e", "f", "g", "a", "b":return MMLEvent.NOTE;
            case "r":return MMLEvent.REST;
            case "q":return MMLEvent.QUANT_RATIO;
            case "@q":return MMLEvent.QUANT_COUNT;
            case "v":return MMLEvent.VOLUME;
            case "@v":return MMLEvent.FINE_VOLUME;
            case "%":return MMLEvent.MOD_TYPE;
            case "@":return MMLEvent.MOD_PARAM;
            case "@i":return MMLEvent.INPUT_PIPE;
            case "@o":return MMLEvent.OUTPUT_PIPE;case "(", ")":return MMLEvent.VOLUME_SHIFT;
            case "&":return MMLEvent.SLUR;
            case "&&":return MMLEvent.SLUR_WEAK;
            case "*":return MMLEvent.PITCHBEND;
            case ",":return MMLEvent.PARAMETER;
            case "$":return MMLEvent.REPEAT_ALL;
            case "[":return MMLEvent.REPEAT_BEGIN;
            case "]":return MMLEvent.REPEAT_END;
            case "|":return MMLEvent.REPEAT_BREAK;
            case "t":return MMLEvent.TEMPO;
        }
        return 0;
    }
    
    
    /** @private [internal] get command letters. */
    @:allow(org.si.sion.sequencer.base)
    private static function _getCommandLetters(list : Array<Dynamic>) : Void
    {
        list[MMLEvent.NOTE] = "c";
        list[MMLEvent.REST] = "r";
        list[MMLEvent.QUANT_RATIO] = "q";
        list[MMLEvent.QUANT_COUNT] = "@q";
        list[MMLEvent.VOLUME] = "v";
        list[MMLEvent.FINE_VOLUME] = "@v";
        list[MMLEvent.MOD_TYPE] = "%";
        list[MMLEvent.MOD_PARAM] = "@";
        list[MMLEvent.INPUT_PIPE] = "@i";
        list[MMLEvent.OUTPUT_PIPE] = "@o";
        list[MMLEvent.VOLUME_SHIFT] = "(";
        list[MMLEvent.SLUR] = "&";
        list[MMLEvent.SLUR_WEAK] = "&&";
        list[MMLEvent.PITCHBEND] = "*";
        list[MMLEvent.PARAMETER] = ",";
        list[MMLEvent.REPEAT_ALL] = "$";
        list[MMLEvent.REPEAT_BEGIN] = "[";
        list[MMLEvent.REPEAT_END] = "]";
        list[MMLEvent.REPEAT_BREAK] = "|";
        list[MMLEvent.TEMPO] = "t";
    }
    
    
    /** @private [internal] get system event string */
    @:allow(org.si.sion.sequencer.base)
    private static function _getSystemEventString(e : MMLEvent) : String
    {
        return _systemEventStrings[e.data];
    }
    
    
    /** @private [internal] get sequence mml string */
    @:allow(org.si.sion.sequencer.base)
    private static function _getSequenceMML(e : MMLEvent) : String
    {
        return ((e.length == -1)) ? "" : _sequenceMMLStrings[e.length];
    }
    
    
    // push event
    private static function _pushMMLEvent(id : Int, data : Int, length : Int) : MMLEvent
    {
        _lastEvent.next = _allocEvent(id, data, length);
        _lastEvent = _lastEvent.next;
        return _lastEvent;
    }
    
    
    // register system event string
    private static function _regSystemEventString(str : String) : Int
    {
        _systemEventStrings[_systemEventIndex++] = str;
        return _systemEventIndex - 1;
    }
    
    
    // register sequence MML string
    private static function _regSequenceMMLStrings(str : String) : Int
    {
        _sequenceMMLStrings[_sequenceMMLIndex++] = str;
        return _sequenceMMLIndex - 1;
    }
    
    
    
    // regular expression
    //--------------------------------------------------
    private static inline var REX_WHITESPACE : Int = 1;
    private static inline var REX_SYSTEM : Int = 2;
    private static inline var REX_COMMAND : Int = 3;
    private static inline var REX_NOTE : Int = 4;
    private static inline var REX_SHIFT_NOTE : Int = 5;
    private static inline var REX_USER_EVENT : Int = 6;
    private static inline var REX_EVENT : Int = 7;
    private static inline var REX_TABLE : Int = 8;
    private static inline var REX_PARAM : Int = 9;
    private static inline var REX_PERIOD : Int = 10;
    private static var _mmlRegExp : EReg = null;
    private static var _lastMatchedPos : Int = 0;

    private static function createRegExp(reset : Bool) : EReg
    {
        if (_mmlRegExp == null || reset) {
            // user defined event letters
            var ude : Array<String> = [];
            for (letter in _userDefinedEventID.keys()) {
                ude.push(letter);
            }
            var uderex : String = (ude.length > 0) ? (ude.join("|")) : "a";  // ('A`) I know its an ad-hok solution...

            var rex : String;
            rex = "(\\s+)";                                            // whitespace (res[1])
            rex += "|(#[^;]*)";                                        // system (res[2])
            rex += "|(";                                               // --all-- (res[3])
            rex += "([a-g])([\\-+#]?)";                                // note (res[4],[5])
            rex += "|(" + uderex + ")";                                // module events (res[6])
            rex += "|(@[qvio]?|&&|!@ns|[rlqovt^<>()\\[\\]/|$%&*,;])";  // default events (res[7])
            rex += "|(\\{.*?\\}[0-9]*\\*?[\\-0-9.]*\\+?[\\-0-9.]*)";   // table event (res[8])
            rex += ")\\s*(-?[0-9]*)";                                  // parameter (res[9])
            rex += "\\s*(\\.*)";                                       // periods (res[10])
            _mmlRegExp = new EReg(rex, "gms");
        }
        
        return _mmlRegExp;
    }
    
    
    
    
    // parser
    //--------------------------------------------------
    /** Prepare to parse. 
     *  @param mml MML String.
     *  @return Returns head MMLEvent. The return value of null means no head event.
     */
    public static function prepareParse(setting : MMLParserSetting, mml : String) : Void
    {
        trace('MMLParser.prepareParse()');
        // set internal parameters
        _setting = setting;
        _mmlString = mml;
        _parsingTime = Math.round(haxe.Timer.stamp() * 1000);
        trace('Creating regexp');
        // create EReg
        createRegExp(true);
        trace('Initializing');
        // initialize
        _initialize();
        trace('Done preparing the parse.');
    }
    
    
    /** Parse mml string. 
     *  @param  interrupt Interrupting interval [ms]. 0 means no interruption. The interrupt appears between each sequence.
     *  @return Returns head MMLEvent. The return value of null means no head event.
     */
    public static function parse(interrupt : Int = 0) : MMLEvent
    {
        var shift : Int;
        var note : Int;
        var halt : Bool;
        var rex : EReg;
        var res : Dynamic;
        var mml2nn : Int = _setting.mml2nn;
        var codeC : Int = "c".charCodeAt(0);

        trace('MMLParser.parse()');

        // set interrupting interval
        _interruptInterval = interrupt;
        _startTime = Math.round(haxe.Timer.stamp() * 1000);
        
        // regular expression
        rex = createRegExp(false);
        
        // parse
        halt = false;
        var res:Array<String> = new Array<String>();


        // internal functions
        //----------------------------------------
        // parse length. The return value of int.MIN_VALUE means abbreviation.
        function __calcLength() : Int{
            if (res[REX_PARAM].length == 0)                 return INT_MIN_VALUE;
            var len : Int = Std.parseInt(res[REX_PARAM]);
            if (len == 0)                 return 0;
            var iLength : Int = Math.floor(_setting.resolution / len);
            if (iLength < 1 || iLength > _setting.resolution) throw errorRangeOver("length", 1, _setting.resolution);
            return iLength;
        }

        // parse param.  ;
        function __param(defaultValue : Int = INT_MIN_VALUE) : Int{
            return ((Std.string(res[REX_PARAM]).length > 0)) ? Std.parseInt(res[REX_PARAM]) : defaultValue;
        };

        // parse periods.
        function __period() : Int{
            return res[REX_PERIOD].length;
        };

        while (rex.matchSub(_mmlString, _lastMatchedPos) && rex.matched(0).length > 0) {
            trace('Parse matched: ' + rex.matched(0));
            // Convert to the array format expected by all the functions
            res.splice(0,res.length); // Reset the matching array
            for (i in 0...REX_PERIOD + 1) {
                res.push(rex.matched(i));
            }

            // skip comments
            if (res[REX_WHITESPACE] == null) {
                if (res[REX_NOTE] != null) {
                    // note events.
                    note = res[REX_NOTE].charCodeAt(0) - codeC;
                    if (note < 0) note += 7;
                    shift = _keySignature[note];
                    switch (Std.string(res[REX_SHIFT_NOTE]))
                    {
                        case "+", "#":shift++;
                        case "-"     :shift--;
                    }
                    _note(_keyScale[note] + shift + mml2nn, __calcLength(), __period());
                }
                else 
                if (res[REX_USER_EVENT] != null) {
                    // user defined events.
                    if (!_userDefinedEventID.exists(res[REX_USER_EVENT])) {
                        throw errorUnknown("REX_USER_EVENT");
                    }

                    addMMLEvent(_userDefinedEventID[res[REX_USER_EVENT]], __param());
                }
                else 
                if (res[REX_EVENT] != null) {
                    // default events.
                    switch (Std.string(res[REX_EVENT]))
                    {
                        case "r":_rest(__calcLength(), __period());
                        case "l":_length(__calcLength(), __period());
                        case "^":_tie(__calcLength(), __period());
                        case "o":_octave(__param(_setting.defaultOctave));
                        case "q":_quant(__param(_setting.defaultQuantRatio));
                        case "@q":_at_quant(__param(_setting.defaultQuantCount));
                        case "v":_volume(__param(_setting.defaultVolume));
                        case "@v":_at_volume(__param(_setting.defaultFineVolume));
                        case "%":_mod_type(__param());
                        case "@":_mod_param(__param());
                        case "@i":_input(__param(0));
                        case "@o":_output(__param(0));
                        case "(":_volumeShift(__param(1));
                        case ")":_volumeShift(-__param(1));
                        case "<":_octaveShift(__param(1));
                        case ">":_octaveShift(-__param(1));
                        case "&":_slur();
                        case "&&":_slurweak();
                        case "*":_portament();
                        case ",":_parameter(__param());
                        case ";":halt = _end_sequence();
                        case "$":_repeatPoint();
                        case "[":_repeatBegin(__param(2));
                        case "]":_repeatEnd(__param());
                        case "|":_repeatBreak();
                        case "!@ns":_noteShift(__param(0));
                        case "t":_tempo(__param(Math.floor(_setting.defaultBPM)));
                        default:throw errorUnknown("REX_EVENT;" + res[REX_EVENT]);
                    }
                }
                else if (res[REX_SYSTEM] != null) {
                    // system command is only available at the top of the channel sequence.
                    if (_lastEvent.id != MMLEvent.SEQUENCE_HEAD) throw errorSyntax(res[0]);
                    // add system event
                    addMMLEvent(MMLEvent.SYSTEM_EVENT, _regSystemEventString(res[REX_SYSTEM]));
                }
                else if (res[REX_TABLE] != null) {
                    // add table event
                    addMMLEvent(MMLEvent.TABLE_EVENT, _regSystemEventString(res[REX_TABLE]));
                }
                else {
                    // syntax error
                    throw errorSyntax(res[0]);
                }
            }  // halt  
            
            if (halt) return null;

            var position = rex.matchedPos();
            if (position == null) throw "EReg matchedPos error";
            //trace('LastMatchedPos: ${position.len} bytes at ${position.pos}');
            _lastMatchedPos = position.pos + position.len;
        }

        // check repeating stac
        // parsing complete

        if (_repeatStac.length != 0) throw errorStacOverflow("[");
        // set last channel's last event.
        if (_lastEvent.id != MMLEvent.SEQUENCE_HEAD) _lastSequenceHead.jump = _lastEvent;

        // calculate parsing time
        _parsingTime = Math.round(haxe.Timer.stamp() * 1000) - _parsingTime;
        
        // clear terminator
        var headEvent : MMLEvent = _terminator.next;
        _terminator.next = null;
        return headEvent;
    }
    
    
    // initialize before parse
    private static function _initialize() : Void
    {
        trace('MMLParser._initialize()');
        // free all remains
        var e : MMLEvent = _terminator.next;
        while (e != null) {
            e = _freeEvent(e);
        }

        // initialize tempraries
        _systemEventIndex = 0;  // system event index
        _sequenceMMLIndex = 0;  // sequence mml index  
        _lastEvent = _terminator;  // clear event chain  
        _lastSequenceHead = _pushMMLEvent(MMLEvent.SEQUENCE_HEAD, 0, 0);  // add first event (SEQUENCE_HEAD).
        if (_cacheMMLString)  addMMLEvent(MMLEvent.DEBUG_INFO, -1);
        _initialize_track();
    }
    
    
    // initialize before starting new track.
    private static function _initialize_track() : Void
    {
        trace("MMLParser._initialize_track()");
        _staticLength = _setting.defaultLength;  // initialize l command value  
        _staticOctave = _setting.defaultOctave;  // initialize o command value  
        _staticNoteShift = 0;  // initialize note shift  
        _isLastEventLength = false;  // initialize l command flag
        trace("MMLP.init_track: 1");
        while (_repeatStac.length > 0) _repeatStac.pop();  // clear repeating pointer stac
        trace("MMLP.init_track: 2");
        //var lastPosition = 0;
        //try { lastPosition = _mmlRegExp.matchedPos().pos; } catch(e:Dynamic) {}
        //trace('MMLP.init_track: 3: lastPosition = $lastPosition');
        _headMMLIndex = _lastMatchedPos;
        trace("MMLP.init_track: 4");
    }
    
    
    
    
    // note
    //------------------------------
    // note
    private static function _note(note : Int, iLength : Int, period : Int) : Void
    {
        note += _staticOctave * 12 + _staticNoteShift;
        if (note < 0) {
            //throw errorNoteOutofRange(note);
            note = 0;
        }
        else 
        if (note > 127) {
            //throw errorNoteOutofRange(note);
            note = 127;
        }
        addMMLEvent(MMLEvent.NOTE, note, __calcLength(iLength, period));
    }
    
    
    // rest
    private static function _rest(iLength : Int, period : Int) : Void
    {
        addMMLEvent(MMLEvent.REST, 0, __calcLength(iLength, period));
    }
    
    
    // length operation
    //------------------------------
    // length
    private static function _length(iLength : Int, period : Int) : Void
    {
        _staticLength = __calcLength(iLength, period);
        _isLastEventLength = true;
    }
    
    
    // tie
    private static function _tie(iLength : Int, period : Int) : Void
    {
        if (_isLastEventLength) {
            _staticLength += __calcLength(iLength, period);
        }
        else 
        if (_lastEvent.id == MMLEvent.REST || _lastEvent.id == MMLEvent.NOTE) {
            _lastEvent.length += __calcLength(iLength, period);
        }
        else {
            throw errorSyntax("tie command");
        }
    }
    
    
    // slur
    private static function _slur() : Void
    {
        addMMLEvent(MMLEvent.SLUR, 0, 0, true);
    }
    
    
    // weak slur
    private static function _slurweak() : Void
    {
        addMMLEvent(MMLEvent.SLUR_WEAK, 0, 0, true);
    }
    
    
    // portament
    private static function _portament() : Void
    {
        addMMLEvent(MMLEvent.PITCHBEND, 0, 0, true);
    }
    
    
    // gate time
    private static function _quant(param : Int) : Void
    {
        if (param < _setting.minQuantRatio || param > _setting.maxQuantRatio) {
            throw errorRangeOver("q", _setting.minQuantRatio, _setting.maxQuantRatio);
        }
        addMMLEvent(MMLEvent.QUANT_RATIO, param);
    }
    
    
    // absolute gate time
    private static function _at_quant(param : Int) : Void
    {
        if (param < _setting.minQuantCount || param > _setting.maxQuantCount) {
            throw errorRangeOver("@q", _setting.minQuantCount, _setting.maxQuantCount);
        }
        addMMLEvent(MMLEvent.QUANT_COUNT, param);
    }
    
    
    // calculate length
    private static function __calcLength(iLength : Int, period : Int) : Int
    {
        // set default value
        if (iLength == INT_MIN_VALUE) iLength = _staticLength;
        // extension by period
        var len : Int = iLength;
        while (period > 0){iLength += len >> (period--);
        }
        return iLength;
    }
    
    
    // pitch operation
    //------------------------------
    // octave
    private static function _octave(param : Int) : Void
    {
        if (param < _setting.minOctave || param > _setting.maxOctave) {
            throw errorRangeOver("o", _setting.minOctave, _setting.maxOctave);
        }
        _staticOctave = param;
    }
    
    
    // octave shift
    private static function _octaveShift(param : Int) : Void
    {
        param *= _setting.octavePolarization;
        _staticOctave += param;
    }
    
    
    // note shift
    private static function _noteShift(param : Int) : Void
    {
        _staticNoteShift += param;
    }
    
    
    // volume
    private static function _volume(param : Int) : Void
    {
        if (param < 0 || param > _setting.maxVolume) {
            throw errorRangeOver("v", 0, _setting.maxVolume);
        }
        addMMLEvent(MMLEvent.VOLUME, param);
    }
    
    
    // fine volume
    private static function _at_volume(param : Int) : Void
    {
        if (param < 0 || param > _setting.maxFineVolume) {
            throw errorRangeOver("@v", 0, _setting.maxFineVolume);
        }
        addMMLEvent(MMLEvent.FINE_VOLUME, param);
    }
    
    
    // volume shift
    private static function _volumeShift(param : Int) : Void
    {
        param *= _setting.volumePolarization;
        if (_lastEvent.id == MMLEvent.VOLUME_SHIFT || _lastEvent.id == MMLEvent.VOLUME) {
            _lastEvent.data += param;
        }
        else {
            addMMLEvent(MMLEvent.VOLUME_SHIFT, param);
        }
    }
    
    
    // repeating
    //------------------------------
    // repeat point
    private static function _repeatPoint() : Void
    {
        addMMLEvent(MMLEvent.REPEAT_ALL, 0);
    }
    
    
    // begin repeating
    private static function _repeatBegin(rep : Int) : Void
    {
        if (rep < 1 || rep > 65535) throw errorRangeOver("[", 1, 65535);
        addMMLEvent(MMLEvent.REPEAT_BEGIN, rep, 0);
        _repeatStac.unshift(_lastEvent);
    }
    
    
    // break repeating
    private static function _repeatBreak() : Void
    {
        if (_repeatStac.length == 0) throw errorStacUnderflow("|");
        addMMLEvent(MMLEvent.REPEAT_BREAK);
        _lastEvent.jump = cast((_repeatStac[0]), MMLEvent);
    }
    
    
    // end repeating
    private static function _repeatEnd(rep : Int) : Void
    {
        if (_repeatStac.length == 0)             throw errorStacUnderflow("]");
        addMMLEvent(MMLEvent.REPEAT_END);
        var beginEvent : MMLEvent = cast((_repeatStac.shift()), MMLEvent);
        _lastEvent.jump = beginEvent;  // rep_end.jump   = rep_start  
        beginEvent.jump = _lastEvent;  // rep_start.jump = rep_end  
        
        // update repeat count
        if (rep != INT_MIN_VALUE) {
            if (rep < 1 || rep > 65535) throw errorRangeOver("]", 1, 65535);
            beginEvent.data = rep;
        }
    }
    
    
    // others
    //------------------------------
    // module type
    private static function _mod_type(param : Int) : Void
    {
        addMMLEvent(MMLEvent.MOD_TYPE, param);
    }
    
    
    // module parameters
    private static function _mod_param(param : Int) : Void
    {
        addMMLEvent(MMLEvent.MOD_PARAM, param);
    }
    
    
    // set input pipe
    private static function _input(param : Int) : Void
    {
        addMMLEvent(MMLEvent.INPUT_PIPE, param);
    }
    
    
    // set output pipe
    private static function _output(param : Int) : Void
    {
        addMMLEvent(MMLEvent.OUTPUT_PIPE, param);
    }
    
    
    // pural parameters
    private static function _parameter(param : Int) : Void
    {
        addMMLEvent(MMLEvent.PARAMETER, param);
    }
    
    
    // sequence change
    private static function _end_sequence() : Bool
    {
        if (_lastEvent.id != MMLEvent.SEQUENCE_HEAD) {
            if ((_lastSequenceHead.next != null) && _lastSequenceHead.next.id == MMLEvent.DEBUG_INFO) {
                var position = _mmlRegExp.matchedPos();
                // memory sequence MMLs id in _lastSequenceHead.next.data
                _lastSequenceHead.next.data = _regSequenceMMLStrings(_mmlString.substring(_headMMLIndex, position.pos));
                var sequence = _mmlString.substring(_headMMLIndex, position.pos);
                trace('***** MML Sequence added "$sequence".');
            }
            addMMLEvent(MMLEvent.SEQUENCE_HEAD, 0);
            if (_cacheMMLString) addMMLEvent(MMLEvent.DEBUG_INFO, -1);
            // Returns true when it has to interrupt.
            if (_interruptInterval == 0) return false;
            return (_interruptInterval < (Math.round(haxe.Timer.stamp() * 1000) - _startTime));
        }
        return false;
    }
    
    
    // tempo
    private static function _tempo(t : Int) : Void
    {
        addMMLEvent(MMLEvent.TEMPO, t);
    }
    
    
    
    
    // errors
    //--------------------------------------------------
    public static function errorUnknown(n : String) : Error
    {
        return new Error("MMLParser Error : Unknown error #" + n + ".");
    }
    
    
    public static function errorNoteOutofRange(note : Int) : Error
    {
        return new Error("MMLParser Error : Note #" + note + " is out of range.");
    }
    
    
    public static function errorSyntax(syn : String) : Error
    {
        return new Error("MMLParser Error : Syntax error '" + syn + "'.");
    }
    
    
    public static function errorRangeOver(cmd : String, min : Int, max : Int) : Error
    {
        return new Error("MMLParser Error : The parameter of '" + cmd + "' command must ragne from " + min + " to " + max + ".");
    }
    
    
    public static function errorStacUnderflow(cmd : String) : Error
    {
        return new Error("MMLParser Error : The stac of '" + cmd + "' command is underflow.");
    }
    
    
    public static function errorStacOverflow(cmd : String) : Error
    {
        return new Error("MMLParser Error : The stac of '" + cmd + "' command is overflow.");
    }
    
    
    public static function errorKeySign(ksign : String) : Error
    {
        return new Error("MMLParser Error : Cannot recognize '" + ksign + "' as a key signiture.");
    }
}


