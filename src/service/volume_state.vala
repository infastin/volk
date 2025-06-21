public class VolumeState : Object {
  private double _volume = 0.0;
  private bool _muted = false;

  public signal void changed();

  public double volume {
    get { return _volume; }
    set { _volume = value; changed(); }
  }

  public bool muted {
    get { return _muted; }
    set { _muted = value; changed(); }
  }

  public void update(double volume, bool muted) {
    _volume = volume;
    _muted = muted;
    changed();
  }
}
