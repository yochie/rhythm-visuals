import java.util.Map;
import java.util.HashMap; 
import java.util.Properties;
import java.io.InputStream; 
import java.io.IOException;
import java.lang.NumberFormatException; 


//Class to be extended by each new mode
//Provides methods for loading config from file, initiating mode, drawing mode and handling midi signals 
public abstract class Mode { 

  //Each implementing class should fill this with its default config vars before calling loadConfig() in constructor
  protected Properties defaultConfig = new Properties();

  //filled by loadConfig()
  protected Properties loadedConfig;

  //runs upon switching to mode
  public abstract void setup();
  
  //runs every frame while this mode is active
  public abstract void draw();

  //called for every midi signal recieved
  //Try to keep short and simple to lighten the load on callback
  //and perform more complex computations in draw() 
  //assumes note signal for parsing bytes
  //TODO: pass raw bytes along in case assumption was wrong
  public abstract void handleMidi(Pad pad, int note, int vel);

  //sets loadedConfig from config file and defaults
  protected void loadConfigFrom(String configFileName) {
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

  //returns int from config string property
  //throws IllegalArgumentException when error parsing string as int
  protected int getIntProp(String propName) {
    int toReturn;
    if (loadedConfig.containsKey(propName)) {
      try {
        toReturn = Integer.parseInt(this.loadedConfig.getProperty(propName));
      } 
      catch (NumberFormatException e) {
        println("WARNING: Config var " + propName + " is not of expected type (integer). Falling back to default config for this parameter.");
        toReturn = Integer.parseInt(this.defaultConfig.getProperty(propName));
      }
    } else {
      println("Error: Couldn't find requested config var : " + propName);
      throw(new IllegalArgumentException());
    }
    return toReturn;
  }

  //returns float from config string property
  //throws IllegalArgumentException when error parsing string as float
  protected float getFloatProp(String propName) {
    float toReturn;
    if (loadedConfig.containsKey(propName)) {
      try {
        toReturn = Float.parseFloat(this.loadedConfig.getProperty(propName));
      } 
      catch (NumberFormatException e) {
        println("WARNING: Config var " + propName + " is not of expected type (float). Falling back to default config for this parameter.");
        toReturn = Float.parseFloat(this.defaultConfig.getProperty(propName));
      }
    } else {
      println("Error: Couldn't find requested config var : " + propName);
      throw(new IllegalArgumentException());
    }
    return toReturn;
  }
}
