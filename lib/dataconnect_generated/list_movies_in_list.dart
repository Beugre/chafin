part of 'example.dart';

class ListMoviesInListVariablesBuilder {
  String movieListId;

  final FirebaseDataConnect _dataConnect;
  ListMoviesInListVariablesBuilder(this._dataConnect, {required  this.movieListId,});
  Deserializer<ListMoviesInListData> dataDeserializer = (dynamic json)  => ListMoviesInListData.fromJson(jsonDecode(json));
  Serializer<ListMoviesInListVariables> varsSerializer = (ListMoviesInListVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<ListMoviesInListData, ListMoviesInListVariables>> execute() {
    return ref().execute();
  }

  QueryRef<ListMoviesInListData, ListMoviesInListVariables> ref() {
    ListMoviesInListVariables vars= ListMoviesInListVariables(movieListId: movieListId,);
    return _dataConnect.query("ListMoviesInList", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ListMoviesInListMovieList {
  final List<ListMoviesInListMovieListMovieListEntriesOnMovieList> movieListEntries_on_movieList;
  ListMoviesInListMovieList.fromJson(dynamic json):
  
  movieListEntries_on_movieList = (json['movieListEntries_on_movieList'] as List<dynamic>)
        .map((e) => ListMoviesInListMovieListMovieListEntriesOnMovieList.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMoviesInListMovieList otherTyped = other as ListMoviesInListMovieList;
    return movieListEntries_on_movieList == otherTyped.movieListEntries_on_movieList;
    
  }
  @override
  int get hashCode => movieListEntries_on_movieList.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieListEntries_on_movieList'] = movieListEntries_on_movieList.map((e) => e.toJson()).toList();
    return json;
  }

  ListMoviesInListMovieList({
    required this.movieListEntries_on_movieList,
  });
}

@immutable
class ListMoviesInListMovieListMovieListEntriesOnMovieList {
  final ListMoviesInListMovieListMovieListEntriesOnMovieListMovie movie;
  final String? note;
  final int position;
  ListMoviesInListMovieListMovieListEntriesOnMovieList.fromJson(dynamic json):
  
  movie = ListMoviesInListMovieListMovieListEntriesOnMovieListMovie.fromJson(json['movie']),
  note = json['note'] == null ? null : nativeFromJson<String>(json['note']),
  position = nativeFromJson<int>(json['position']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMoviesInListMovieListMovieListEntriesOnMovieList otherTyped = other as ListMoviesInListMovieListMovieListEntriesOnMovieList;
    return movie == otherTyped.movie && 
    note == otherTyped.note && 
    position == otherTyped.position;
    
  }
  @override
  int get hashCode => Object.hash(movie.hashCode, note.hashCode, position.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movie'] = movie.toJson();
    if (note != null) {
      json['note'] = nativeToJson<String?>(note);
    }
    json['position'] = nativeToJson<int>(position);
    return json;
  }

  ListMoviesInListMovieListMovieListEntriesOnMovieList({
    required this.movie,
    this.note,
    required this.position,
  });
}

@immutable
class ListMoviesInListMovieListMovieListEntriesOnMovieListMovie {
  final String id;
  final String title;
  final int year;
  ListMoviesInListMovieListMovieListEntriesOnMovieListMovie.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  title = nativeFromJson<String>(json['title']),
  year = nativeFromJson<int>(json['year']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMoviesInListMovieListMovieListEntriesOnMovieListMovie otherTyped = other as ListMoviesInListMovieListMovieListEntriesOnMovieListMovie;
    return id == otherTyped.id && 
    title == otherTyped.title && 
    year == otherTyped.year;
    
  }
  @override
  int get hashCode => Object.hash(id.hashCode, title.hashCode, year.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['title'] = nativeToJson<String>(title);
    json['year'] = nativeToJson<int>(year);
    return json;
  }

  ListMoviesInListMovieListMovieListEntriesOnMovieListMovie({
    required this.id,
    required this.title,
    required this.year,
  });
}

@immutable
class ListMoviesInListData {
  final ListMoviesInListMovieList? movieList;
  ListMoviesInListData.fromJson(dynamic json):
  
  movieList = json['movieList'] == null ? null : ListMoviesInListMovieList.fromJson(json['movieList']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMoviesInListData otherTyped = other as ListMoviesInListData;
    return movieList == otherTyped.movieList;
    
  }
  @override
  int get hashCode => movieList.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (movieList != null) {
      json['movieList'] = movieList!.toJson();
    }
    return json;
  }

  ListMoviesInListData({
    this.movieList,
  });
}

@immutable
class ListMoviesInListVariables {
  final String movieListId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ListMoviesInListVariables.fromJson(Map<String, dynamic> json):
  
  movieListId = nativeFromJson<String>(json['movieListId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMoviesInListVariables otherTyped = other as ListMoviesInListVariables;
    return movieListId == otherTyped.movieListId;
    
  }
  @override
  int get hashCode => movieListId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieListId'] = nativeToJson<String>(movieListId);
    return json;
  }

  ListMoviesInListVariables({
    required this.movieListId,
  });
}

