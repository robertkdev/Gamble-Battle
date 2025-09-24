extends Object
class_name Strings

static func join(arr: Array, sep: String) -> String:
    var out := ""
    for i in range(arr.size()):
        if i > 0:
            out += sep
        out += str(arr[i])
    return out

