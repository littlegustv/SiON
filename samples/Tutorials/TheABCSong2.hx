// simple example
import org.si.sion.SiONDriver;
import org.si.sion.SiONData;

import openfl.display.Sprite;
import org.si.sion.*;

class TheABCSong2 extends Sprite
{
    public var driver : SiONDriver = new SiONDriver();
    public var data : SiONData;
    
    public function new()
    {
        super();
        data = driver.compile("t100 l8 [ccggaag4 ffeeddc4 | [ggffeed4]2 ]2");
        driver.play(data);
    }
}


