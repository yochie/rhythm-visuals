public class AboutMode extends Mode {
  private PImage aboutLogo;

  public AboutMode() {
    this.modeName = "À propos - About";

    //sets loaded config
    this.loadConfigFrom("about_config.properties");
    println("About config: ");
    println(this.loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: About");
    this.aboutLogo = loadImage("about.png");
    this.aboutLogo.resize(width, 0);      
    if (this.aboutLogo.height > height) {
      this.aboutLogo.resize(0, height);
    }
  }

  public void draw() {
    this.noModePressChecking();
    imageMode(CENTER);
    image(this.aboutLogo, width/2, height/2);
    imageMode(CORNERS);
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
  }
}
