/** A photo filter based on Photoshop action by Amatorka
 http://amatorka.deviantart.com/art/Amatorka-Action-2-121069631
 */

// Note: If you want to use this effect you have to add lookup_amatorka.png
//       from Resources folder to your application bundle.

#if !os(Linux)

public class AmatorkaFilter: LookupFilter {
    public override init() {
        super.init()
        
        do {
            try ({lookupImage = try PictureInput(imageName:"lookup_amatorka.png")})()
        } catch {
            print("ERROR: Unable to create PictureInput \(error)")
        }
        
        ({intensity = 1.0})()
    }
}
#endif
