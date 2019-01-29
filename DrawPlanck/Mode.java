public interface Mode {
    public void setup();
    public void draw();
    
    public void handleMidi(int pad, int note, int vel);
}