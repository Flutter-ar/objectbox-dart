import "iduid.dart";
import "modelinfo.dart";
import "property.dart";

class Entity {
  IdUid id, lastPropertyId;
  String name;
  List<Property> properties;
  ModelInfo model;

  Entity(this.id, this.lastPropertyId, this.name, this.properties, this.model) {
    validate();
  }

  Entity.fromMap(Map<String, dynamic> data, this.model) {
    id = IdUid(data["id"]);
    if (data.containsKey("lastPropertyId") && data["lastPropertyId"] != null)
      lastPropertyId = IdUid(data["lastPropertyId"]);
    name = data["name"];
    properties = data["properties"].map<Property>((p) => Property.fromMap(p, this)).toList();
    validate();
  }

  void validate() {
    if (name == null || name.length == 0) throw Exception("name is not defined");
    if (properties == null) throw Exception("properties is null");
    if (model == null) throw Exception("model is null");

    if (properties.length == 0) {
      if (lastPropertyId != null) throw Exception("lastPropertyId is not null although there are no properties");
    } else {
      var entity = this;
      bool lastPropertyIdFound = false;

      properties.forEach((p) {
        if (p.entity != entity)
          throw Exception("property '${p.name}' with id ${p.id.toString()} has incorrect parent entity reference");
        if (lastPropertyId.id < p.id.id)
          throw Exception(
              "lastPropertyId ${lastPropertyId.toString()} is lower than the one of property '${p.name}' with id ${p.id.toString()}");
        if (lastPropertyId.id == p.id.id) {
          if (lastPropertyId.uid != p.id.uid)
            throw Exception(
                "lastPropertyId ${lastPropertyId.toString()} does not match property '${p.name}' with id ${p.id.toString()}");
          lastPropertyIdFound = true;
        }
      });

      if (properties.length > 0 && !lastPropertyIdFound)
        throw Exception("lastPropertyId ${lastPropertyId.toString()} does not match any property");
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["lastPropertyId"] = lastPropertyId == null ? null : lastPropertyId.toString();
    ret["name"] = name;
    ret["properties"] = properties.map((p) => p.toMap()).toList();
    return ret;
  }

  Property findPropertyByUid(int uid) {
    int idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  Property findPropertyByName(String name) {
    final found = properties.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
    if (found.length == 0) return null;
    if (found.length >= 2) throw Exception("ambiguous property name: $name; please specify a UID in its annotation");
    return found[0];
  }

  Property findSameProperty(Property other) {
    Property ret;
    if (other.id.uid != 0) ret = findPropertyByUid(other.id.uid);
    if (ret == null) ret = findPropertyByName(other.name);
    return ret;
  }

  Property createProperty(String name, [int uid = 0]) {
    int id = 1;
    if (properties.length > 0) id = lastPropertyId.id + 1;
    if (uid != 0 && model.containsUid(uid)) throw Exception("uid already exists: $uid");
    int uniqueUid = uid == 0 ? model.generateUid() : uid;

    var property = Property(IdUid.create(id, uniqueUid), name, 0, 0, this);
    properties.add(property);
    lastPropertyId = property.id;
    return property;
  }

  Property createCopiedProperty(Property prop) {
    Property ret = createProperty(prop.name, prop.id.uid);
    ret.type = prop.type;
    ret.flags = prop.flags;
    return ret;
  }

  void _recalculateLastPropertyId() {
    // assign id/uid of property with largest id to lastPropertyId
    lastPropertyId = null;
    properties.forEach((p) {
      if (lastPropertyId == null || p.id.id > lastPropertyId.id) lastPropertyId = p.id;
    });
  }

  void removeProperty(Property prop) {
    if (prop == null) return;
    Property foundProp = findSameProperty(prop);
    if (foundProp == null)
      throw Exception("cannot remove property '${prop.name}' with id ${prop.id.toString()}: not found");
    properties = properties.where((p) => p != foundProp).toList();
    model.retiredPropertyUids.add(prop.id.uid);
    _recalculateLastPropertyId();
  }

  bool containsUid(int searched) {
    if (id.uid == searched) return true;
    if (lastPropertyId != null && lastPropertyId.uid == searched) return true;
    if (properties.indexWhere((p) => p.containsUid(searched)) != -1) return true;
    return false;
  }
}
