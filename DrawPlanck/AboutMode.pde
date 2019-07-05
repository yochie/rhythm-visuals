public class AboutMode extends Mode {
  private PImage logo;

  public AboutMode() {
    this.modeName = "À propos";

    //sets loaded config
    this.loadConfigFrom("about_config.properties");
    println("About config: ");
    println(this.loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: About");
    this.logo = loadImage("about.png");
  }

  public void draw() {
    this.noModePressChecking();
    imageMode(CENTER);
    image(this.logo, width/2, height/2);
    imageMode(CORNERS);
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
  }
}
