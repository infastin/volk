[DBus(name = "com.github.infastin.volk")]
public interface VolumeProxy : Object {
  public abstract double volume { get; set; }
  public abstract bool muted { get; set; }
  public abstract void add_volume(double delta) throws Error;
}
