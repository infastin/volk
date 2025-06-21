namespace Wp {
  [CCode (cheader_filename = "wp/wp.h", type_id = "wp_spa_type_get_type ()")]
  [SimpleType]
  public struct SpaType : uint32 {
  }

	[CCode (cheader_filename = "wp/wp.h", type_id = "wp_object_interest_get_type ()")]
  public class ObjectInterest : GLib.Object {
    public ObjectInterest(GLib.Type gtype, ...);
    public ObjectInterest.valist(GLib.Type gtype, va_list args);
  }

	[CCode (cheader_filename = "wp/wp.h", type_id = "wp_object_manager_get_type ()")]
	public class ObjectManager : GLib.Object {
    public void add_interest(GLib.Type gtype, ...);
    public GLib.Object? lookup(GLib.Type gtype, ...);
  }
}
