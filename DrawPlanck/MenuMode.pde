public class MenuMode extends Mode {

  private List<String> menu = new ArrayList<String>();

  private int optionIndex;

  public MenuMode() {
    //this.defaultConfig.setProperty("WORDS", "Triolets, Gigue, Lentement, Rapidement");

    //sets loaded config
    this.loadConfigFrom("menu_config.properties");
    println("Menu config: ");
    println(this.loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: Menu");
    
    this.optionIndex = -1;
  }

  public void draw() {
    this.noModePressChecking();
    if (optionIndex > 0){
      //TODO:activate mode
    } else {
      //TODO:Draw options
    }
   
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    
    //filter out unassigned notes, note_off messages and unused pads
    if (pad != null && vel > 0 && pad.name.equals("BOTTOM_RIGHT_NOTE")) {
      
      //TODO:cycle menu
      
    } else {
      switch (pad.name) {
      case "TOP_LEFT_NOTE":
        optionIndex = 0;
        break;
      case "TOP_RIGHT_NOTE":
        optionIndex = 1;
        break;
      case "BOTTOM_LEFT_NOTE":
        optionIndex = 2;
        break;        
      }
    }
  }
}
