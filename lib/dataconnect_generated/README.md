# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListPublicMovieLists
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listPublicMovieLists().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListPublicMovieListsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listPublicMovieLists();
ListPublicMovieListsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listPublicMovieLists().ref();
ref.execute();

ref.subscribe(...);
```


### ListMoviesInList
#### Required Arguments
```dart
String movieListId = ...;
ExampleConnector.instance.listMoviesInList(
  movieListId: movieListId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMoviesInListData, ListMoviesInListVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMoviesInList(
  movieListId: movieListId,
);
ListMoviesInListData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String movieListId = ...;

final ref = ExampleConnector.instance.listMoviesInList(
  movieListId: movieListId,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreatePublicMovieList
#### Required Arguments
```dart
String name = ...;
ExampleConnector.instance.createPublicMovieList(
  name: name,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreatePublicMovieList, we created `CreatePublicMovieListBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreatePublicMovieListVariablesBuilder {
  ...
   CreatePublicMovieListVariablesBuilder description(String? t) {
   _description.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.createPublicMovieList(
  name: name,
)
.description(description)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreatePublicMovieListData, CreatePublicMovieListVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createPublicMovieList(
  name: name,
);
CreatePublicMovieListData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String name = ...;

final ref = ExampleConnector.instance.createPublicMovieList(
  name: name,
).ref();
ref.execute();
```


### AddMovieToList
#### Required Arguments
```dart
String movieListId = ...;
String movieId = ...;
int position = ...;
ExampleConnector.instance.addMovieToList(
  movieListId: movieListId,
  movieId: movieId,
  position: position,
).execute();
```

#### Optional Arguments
We return a builder for each query. For AddMovieToList, we created `AddMovieToListBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class AddMovieToListVariablesBuilder {
  ...
   AddMovieToListVariablesBuilder note(String? t) {
   _note.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.addMovieToList(
  movieListId: movieListId,
  movieId: movieId,
  position: position,
)
.note(note)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<AddMovieToListData, AddMovieToListVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.addMovieToList(
  movieListId: movieListId,
  movieId: movieId,
  position: position,
);
AddMovieToListData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String movieListId = ...;
String movieId = ...;
int position = ...;

final ref = ExampleConnector.instance.addMovieToList(
  movieListId: movieListId,
  movieId: movieId,
  position: position,
).ref();
ref.execute();
```

