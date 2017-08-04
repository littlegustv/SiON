//----------------------------------------------------------------------------------------------------
// PDX data class
//  Copyright (c) 2009 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------


package org.si.sound.mdx;


import openfl.events.*;
import openfl.utils.ByteArray;
import org.si.sion.utils.SiONUtil;
import org.si.utils.AbstructLoader;


/** PDX data class */
class PDXData extends AbstructLoader
{
    // variables
    //--------------------------------------------------------------------------------
    /** PDX file name */
    public var fileName : String = "";
    /** ADPCM data */
    public var adpcmData : Array<ByteArray>;
    /** extracted PCM data */
    public var pcmData : Array<Array<Float>>;
    
    
    
    
    // constructor
    //--------------------------------------------------------------------------------
    /** constructor */
    public function new()
    {
        super();
        adpcmData = new Array<ByteArray>();
        pcmData = new Array<Array<Float>>();
    }
    
    
    
    
    // operations
    //--------------------------------------------------------------------------------
    /** Clear. */
    public function clear() : PDXData
    {
        fileName = "";
        for (i in 0...96){
            adpcmData[i] = null;
            pcmData[i] = null;
        }
        return this;
    }
    
    
    /** Load PDX data from byteArray. 
     *  @param bytes ByteArray of PDX data
     *  @param extractAll extract all ADPCM data to PCM data
     */
    public function loadBytes(bytes : ByteArray, extractAll : Bool = true) : PDXData
    {
        var offset : Int;
        var length : Int;
        
        clear();
        bytes.endian = BIG_ENDIAN;
        
        for (i in 0...96){
            bytes.position = i * 8;
            offset = bytes.readUnsignedInt();
            length = bytes.readUnsignedInt();
            if (offset != 0 && length != 0) {
                adpcmData[i] = new ByteArray();
                bytes.position = offset;
                bytes.readBytes(adpcmData[i], 0, length);
                if (extractAll)                     pcmData[i] = SiONUtil.extractYM2151ADPCM(adpcmData[i]);
            }
        }
        
        return this;
    }
    
    
    /** extract adpcm data 
     *  @param noteNumber note number to extract.
     *  @return extracted PCM data (monoral). returns null when the ADPCM data is not assigned on specifyed note number.
     */
    public function extract(noteNumber : Int) : Array<Float>
    {
        if (pcmData[noteNumber] != null)             return pcmData[noteNumber];
        if (adpcmData[noteNumber] == null)             return null;
        pcmData[noteNumber] = SiONUtil.extractYM2151ADPCM(adpcmData[noteNumber]);
        return pcmData[noteNumber];
    }
}


