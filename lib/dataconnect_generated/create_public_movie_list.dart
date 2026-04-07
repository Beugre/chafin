part of 'example.dart';

class CreatePublicMovieListVariablesBuilder {
  String name;
  Optional<String> _description = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  CreatePublicMovieListVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }

  CreatePublicMovieListVariablesBuilder(this._dataConnect, {required  this.name,});
  Deserializer<CreatePublicMovieListData> dataDeserializer = (dynamic json)  => CreatePublicMovieListData.fromJson(jsonDecode(json));
  Serializer<CreatePublicMovieListVariables> varsSerializer = (CreatePublicMovieListVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreatePublicMovieListData, CreatePublicMovieListVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreatePublicMovieListData, CreatePublicMovieListVariables> ref() {
    CreatePublicMovieListVariables vars= CreatePublicMovieListVariables(name: name,description: _description,);
    return _dataConnect.mutation("CreatePublicMovieList", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreatePublicMovieListMovieListInsert {
  final String id;
  CreatePublicMovieListMovieListInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreatePublicMovieListMovieListInsert otherTyped = other as CreatePublicMovieListMovieListInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreatePublicMovieListMovieListInsert({
    required this.id,
  });
}

@immutable
class CreatePublicMovieListData {
  final CreatePublicMovieListMovieListInsert movieList_insert;
  CreatePublicMovieListData.fromJson(dynamic json):
  
  movieList_insert = CreatePublicMovieListMovieListInsert.fromJson(json['movieList_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreatePublicMovieListData otherTyped = other as CreatePublicMovieListData;
    return movieList_insert == otherTyped.movieList_insert;
    
  }
  @override
  int get hashCode => movieList_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieList_insert'] = movieList_insert.toJson();
    return json;
  }

  CreatePublicMovieListData({
    required this.movieList_insert,
  });
}

@immutable
class CreatePublicMovieListVariables {
  final String name;
  late final Optional<String>description;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreatePublicMovieListVariables.fromJson(Map<String, dynamic> json):
  
  name = nativeFromJson<String>(json['name']) {
  
  
  
    description = Optional.optional(nativeFromJson, nativeToJson);
    description.value = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreatePublicMovieListVariables otherTyped = other as CreatePublicMovieListVariables;
    return name == otherTyped.name && 
    description == otherTyped.description;
    
  }
  @override
  int get hashCode => Object.hash(name.hashCode, description.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['name'] = nativeToJson<String>(name);
    if(description.state == OptionalState.set) {
      json['description'] = description.toJson();
    }
    return json;
  }

  CreatePublicMovieListVariables({
    required this.name,
    required this.description,
  });
}

