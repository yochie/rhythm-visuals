public interface Mode {
    public void setup();
    public void draw();
    
    public void handleMidi(Pad pad, int note, int vel);
}