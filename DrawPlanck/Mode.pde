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
    this.loadedConfig = new Properties(defaultConfig);
    InputStream is = null;
    try {
      is = createInput(configFileName);
      this.loadedConfig.load(is);
    } 
    catch (IOException ex) {
      println("Error reading config file.");
    }
  }
  
  protected int getIntProp(String propName){
    int toReturn = -1;
    try {
      toReturn = Integer.parseInt(this.loadedConfig.getProperty(propName));
    } catch (NumberFormatException e) {
       println("WARNING: Config var " + propName + " is not of expected type (integer). Falling back to default config for this parameter.");
       toReturn = Integer.parseInt(this.defaultConfig.getProperty(propName));
    }
    return toReturn;
  }
  
  protected float getFloatProp(String propName){
   float toReturn = -1;
    try {
      toReturn = Float.parseFloat(this.loadedConfig.getProperty(propName));
    } catch (NumberFormatException e) {
       println("WARNING: Config var " + propName + " is not of expected type (float). Falling back to default config for this parameter.");
       toReturn = Float.parseFloat(this.defaultConfig.getProperty(propName));
    }
    return toReturn;
  }
}
