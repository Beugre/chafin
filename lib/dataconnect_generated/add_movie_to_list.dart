part of 'example.dart';

class AddMovieToListVariablesBuilder {
  String movieListId;
  String movieId;
  Optional<String> _note = Optional.optional(nativeFromJson, nativeToJson);
  int position;

  final FirebaseDataConnect _dataConnect;  AddMovieToListVariablesBuilder note(String? t) {
   _note.value = t;
   return this;
  }

  AddMovieToListVariablesBuilder(this._dataConnect, {required  this.movieListId,required  this.movieId,required  this.position,});
  Deserializer<AddMovieToListData> dataDeserializer = (dynamic json)  => AddMovieToListData.fromJson(jsonDecode(json));
  Serializer<AddMovieToListVariables> varsSerializer = (AddMovieToListVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<AddMovieToListData, AddMovieToListVariables>> execute() {
    return ref().execute();
  }

  MutationRef<AddMovieToListData, AddMovieToListVariables> ref() {
    AddMovieToListVariables vars= AddMovieToListVariables(movieListId: movieListId,movieId: movieId,note: _note,position: position,);
    return _dataConnect.mutation("AddMovieToList", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class AddMovieToListMovieListEntryInsert {
  final String movieListId;
  final String movieId;
  AddMovieToListMovieListEntryInsert.fromJson(dynamic json):
  
  movieListId = nativeFromJson<String>(json['movieListId']),
  movieId = nativeFromJson<String>(json['movieId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddMovieToListMovieListEntryInsert otherTyped = other as AddMovieToListMovieListEntryInsert;
    return movieListId == otherTyped.movieListId && 
    movieId == otherTyped.movieId;
    
  }
  @override
  int get hashCode => Object.hash(movieListId.hashCode, movieId.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieListId'] = nativeToJson<String>(movieListId);
    json['movieId'] = nativeToJson<String>(movieId);
    return json;
  }

  AddMovieToListMovieListEntryInsert({
    required this.movieListId,
    required this.movieId,
  });
}

@immutable
class AddMovieToListData {
  final AddMovieToListMovieListEntryInsert movieListEntry_insert;
  AddMovieToListData.fromJson(dynamic json):
  
  movieListEntry_insert = AddMovieToListMovieListEntryInsert.fromJson(json['movieListEntry_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddMovieToListData otherTyped = other as AddMovieToListData;
    return movieListEntry_insert == otherTyped.movieListEntry_insert;
    
  }
  @override
  int get hashCode => movieListEntry_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieListEntry_insert'] = movieListEntry_insert.toJson();
    return json;
  }

  AddMovieToListData({
    required this.movieListEntry_insert,
  });
}

@immutable
class AddMovieToListVariables {
  final String movieListId;
  final String movieId;
  late final Optional<String>note;
  final int position;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  AddMovieToListVariables.fromJson(Map<String, dynamic> json):
  
  movieListId = nativeFromJson<String>(json['movieListId']),
  movieId = nativeFromJson<String>(json['movieId']),
  position = nativeFromJson<int>(json['position']) {
  
  
  
  
    note = Optional.optional(nativeFromJson, nativeToJson);
    note.value = json['note'] == null ? null : nativeFromJson<String>(json['note']);
  
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final AddMovieToListVariables otherTyped = other as AddMovieToListVariables;
    return movieListId == otherTyped.movieListId && 
    movieId == otherTyped.movieId && 
    note == otherTyped.note && 
    position == otherTyped.position;
    
  }
  @override
  int get hashCode => Object.hash(movieListId.hashCode, movieId.hashCode, note.hashCode, position.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieListId'] = nativeToJson<String>(movieListId);
    json['movieId'] = nativeToJson<String>(movieId);
    if(note.state == OptionalState.set) {
      json['note'] = note.toJson();
    }
    json['position'] = nativeToJson<int>(position);
    return json;
  }

  AddMovieToListVariables({
    required this.movieListId,
    required this.movieId,
    required this.note,
    required this.position,
  });
}

