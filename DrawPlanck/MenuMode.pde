public class MenuMode extends Mode {

  private List<String> menu = new ArrayList<String>();

  private int choiceIndex;
  private int menuIndex;
  final private int positions[][] = {{width/4, height/4}, {3*width/4, height/4}, {width/4, 3*height/4}, {3*width/4, 3*height/4}};

  public MenuMode() {
    this.modeName = "Menu";

    //sets loaded config
    this.loadConfigFrom("menu_config.properties");
    println("Menu config: ");
    println(this.loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: Menu");

    this.choiceIndex = -1;
    this.menuIndex = 0;
  }

  public void draw() {
    this.noModePressChecking();
    if (choiceIndex >= 0 && ((menuIndex * 3) + choiceIndex) < modes.size()) {
      nextMode =(menuIndex * 3) + choiceIndex;
    } else {
      line(width/2, 0, width/2, height);
      line(0, height/2, width, height/2);
      textSize(32);

      int optionIndex = 0;
      while ((((menuIndex * 3) + optionIndex) < modes.size()) && optionIndex < 3) {
        text(modes.get((menuIndex * 3) + optionIndex).modeName, positions[optionIndex][0], positions[optionIndex][1]);
        optionIndex++;
      }
      text("...", positions[3][0], positions[3][1]);
    }
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    
    //filter out unassigned notes, note_off messages and unused pads
    if (pad != null && vel > 0) {
      switch (pad.name) {
      case "BOTTOM_RIGHT_NOTE" :
        if (menuIndex < modes.size() / 3) {
          menuIndex++;
        } else {
          menuIndex = 0;
        }
        break;
      case "TOP_LEFT_NOTE":
        choiceIndex = 0;
        break;
      case "TOP_RIGHT_NOTE":
        choiceIndex = 1;
        break;
      case "BOTTOM_LEFT_NOTE":
        choiceIndex = 2;
        break;
      }
      println(choiceIndex);
    }
  }
}
