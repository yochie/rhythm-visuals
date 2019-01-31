import java.util.Map;
import java.util.HashMap; 
import java.util.Properties;
import java.io.InputStream; 
import java.io.IOException;
import java.lang.NumberFormatException; 

public abstract class Mode {
    
  //Each implementing class should fill this with its default config vars
  protected Properties defaultConfig = new Properties();
  
  //filled by loadConfig()
  protected Properties loadedConfig;
  
  public abstract void setup();
  public abstract void draw();
  
  public abstract void handleMidi(Pad pad, int note, int vel);
  
  //sets loadedConfig from config file and defaults
  protected void loadConfigFrom(String configFileName){
    loadedConfig = new Properties(defaultConfig);
    InputStream is = null;
    try {
      is = createInput(configFileName);
      loadedConfig.load(is);
    } 
    catch (IOException ex) {
      println("Error reading config file.");
    }
  }
  
  protected int getIntProp(String propName){
    int toReturn = -1;
    try {
      toReturn = Integer.parseInt(loadedConfig.getProperty(propName));
    } catch (NumberFormatException e) {
       println("Config var is not of expected type.");
    }
    return toReturn;
  }
  
  protected float getFloatProp(String propName){
   float toReturn = -1;
    try {
      toReturn = Float.parseFloat(loadedConfig.getProperty(propName));
    } catch (NumberFormatException e) {
       println("Config var is not of expected type.");
    }
    return toReturn;
  }
}
