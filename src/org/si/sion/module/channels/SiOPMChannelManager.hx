//----------------------------------------------------------------------------------------------------
// SiOPM sound channel manager
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.module.channels;

import org.si.sion.module.SiOPMModule;


/** @private SiOPM sound channel manager */
class SiOPMChannelManager
{
    public var length(get, never) : Int;

    // constants
    //--------------------------------------------------
    public static inline var CT_CHANNEL_FM : Int = 0;
    public static inline var CT_CHANNEL_PCM : Int = 1;
    public static inline var CT_CHANNEL_SAMPLER : Int = 2;
    public static inline var CT_CHANNEL_KS : Int = 3;
    public static inline var CT_MAX : Int = 4;
    
    
    
    
    // variables
    //--------------------------------------------------
    /** class instance of SiOPMChannelBase */
    private var _channelClass : Class<Dynamic>;
    /** channel type */
    private var _channelType : Int;
    /** terminator */
    private var _term : SiOPMChannelBase;
    /** channel count */
    private var _length : Int;
    
    
    
    // properties
    //--------------------------------------------------
    /** allocated channel count */
    private function get_length() : Int{return _length;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    /** constructor */
    public function new(channelClass : Class<Dynamic>, channelType : Int)
    {
        _channelType = channelType;
        _channelClass = channelClass;
        _term = new SiOPMChannelBase(_chip);
        _term._isFree = false;
        _term._next = _term;
        _term._prev = _term;
        _length = 0;
    }
    
    
    
    
    // operations
    //--------------------------------------------------
    // allocate channels.
    private function _alloc(count : Int) : Void
    {
        var i : Int;
        var newInstance : SiOPMChannelBase;
        var imax : Int = count - _length;
        // allocate new channels
        for (i in 0...imax){
            newInstance = Type.createInstance(_channelClass, [_chip]);
            newInstance._channelType = _channelType;
            newInstance._isFree = true;
            newInstance._prev = _term._prev;
            newInstance._next = _term;
            newInstance._prev._next = newInstance;
            newInstance._next._prev = newInstance;
            _length++;
        }
    }
            
    
    // get new channel. returns null when the channel count is overflow.
    private function _newChannel(prev : SiOPMChannelBase, bufferIndex : Int) : SiOPMChannelBase
    {
        var newChannel : SiOPMChannelBase;
        if (_term._next._isFree) {
            // The head channel is free -> The head will be a new channel.
            newChannel = _term._next;
            newChannel._prev._next = newChannel._next;
            newChannel._next._prev = newChannel._prev;
        }
        else {
        // trace('SiOPMChannelManager: else', Std.string( _channelClass ) );
            // The head channel is active -> channel overflow.
            // create new channel.
            newChannel = Type.createInstance(_channelClass, [_chip]);
            newChannel._channelType = _channelType;
            _length++;
        }
        
        // set newChannel to tail and activate.
        newChannel._isFree = false;
        newChannel._prev = _term._prev;
        newChannel._next = _term;
        newChannel._prev._next = newChannel;
        newChannel._next._prev = newChannel;

        // initialize
        newChannel.initialize(prev, bufferIndex);

        return newChannel;
    }
    
    
    // delete channel.
    private function _deleteChannel(ch : SiOPMChannelBase) : Void
    {
        ch._isFree = true;
        ch._prev._next = ch._next;
        ch._next._prev = ch._prev;
        ch._prev = _term;
        ch._next = _term._next;
        ch._prev._next = ch;
        ch._next._prev = ch;
    }
    
    
    // initialize all channels
    private function _initializeAll() : Void
    {
        var ch : SiOPMChannelBase;
        ch = _term._next;
        while (ch != _term){
            ch._isFree = true;
            ch.initialize(null, 0);
            ch = ch._next;
        }
    }
    
    
    // reset all channels
    private function _resetAll() : Void
    {
        var ch : SiOPMChannelBase;
        ch = _term._next;
        while (ch != _term){
            ch._isFree = true;
            ch.reset();
            ch = ch._next;
        }
    }
    
    
    
    
    // factory
    //----------------------------------------
    private static var _chip : SiOPMModule;  // module instance  
    private static var _channelManagers : Array<SiOPMChannelManager>;  // manager list  
    
    
    /** initialize */
    public static function initialize(chip : SiOPMModule) : Void
    {
        trace('********** SiOPMChannelManager.initialize($chip) called');
        _chip = chip;
        _channelManagers = new Array<SiOPMChannelManager>();
        _channelManagers[CT_CHANNEL_FM] = new SiOPMChannelManager(SiOPMChannelFM, CT_CHANNEL_FM);
        _channelManagers[CT_CHANNEL_PCM] = new SiOPMChannelManager(SiOPMChannelPCM, CT_CHANNEL_PCM);
        _channelManagers[CT_CHANNEL_SAMPLER] = new SiOPMChannelManager(SiOPMChannelSampler, CT_CHANNEL_SAMPLER);
        _channelManagers[CT_CHANNEL_KS] = new SiOPMChannelManager(SiOPMChannelKS, CT_CHANNEL_KS);
    }
    
    
    /** initialize all channels */
    public static function initializeAllChannels() : Void
    {
        // initialize all channels
        for (mng in _channelManagers){
            mng._initializeAll();
        }
    }
    
    
    /** reset all channels */
    public static function resetAllChannels() : Void
    {
        // reset all channels
        for (mng in _channelManagers){
            mng._resetAll();
        }
    }
    
    
    /** New channel with initializing. */
    public static function newChannel(type : Int, prev : SiOPMChannelBase, bufferIndex : Int) : SiOPMChannelBase
    {
        var channelManager = _channelManagers[type];
        var returnValue = channelManager._newChannel(prev, bufferIndex);
        return returnValue;
    }
    
    
    /** Free channel. */
    public static function deleteChannel(channel : SiOPMChannelBase) : Void
    {
        _channelManagers[channel._channelType]._deleteChannel(channel);
    }
}


