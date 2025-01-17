open React.Dom.Dsl
open Html

let%component make ~(viewMode : Shape.Profile.viewMode) ~user =
  let viewMode, changeOffset = Hook.useViewMode ~route:viewMode in
  let username, limit, offset =
    match viewMode with
    | Author (username, limit, offset) -> username, limit, offset
    | Favorited (username, limit, offset) -> username, limit, offset
  in
  let profile = Hook.useProfile ~username in
  let articles, setArticles = Hook.useArticlesInProfile ~viewMode in
  let follow, onFollowClick = Hook.useFollowInProfile ~profile ~user in
  let toggleFavoriteBusy, onToggleFavorite = Hook.useToggleFavorite ~setArticles ~user in
  let isArticlesBusy = articles |> Async_result.isBusy in
  div
    [| className "profile-page" |]
    [
      div
        [| className "user-info" |]
        [
          div
            [| className "container" |]
            [
              div
                [| className "row" |]
                [
                  div
                    [| className "col-xs-12 col-md-10 offset-md-1" |]
                    [
                      Option.bind (Async_result.getOk profile) (fun (user : Shape.author) ->
                        if user.image = "" then None else Some user.image
                      )
                      |> Option.map (fun src -> img [| Prop.src src; className "user-img" |] [])
                      |> Option.value ~default:(img [| className "user-img" |] []);
                      h4 [||]
                        [
                          ( match profile with
                          | Init | Loading | Reloading (Error _) | Complete (Error _) -> "..."
                          | Reloading (Ok user) | Complete (Ok user) -> user.username
                          )
                          |> React.string;
                        ];
                      ( match profile with
                      | Init | Loading | Reloading (Error _) | Complete (Error _) -> React.null
                      | Reloading (Ok user) | Complete (Ok user) ->
                        user.bio |> Option.map (fun bio -> bio |> React.string) |> Option.value ~default:React.null
                      );
                      ( match profile with
                      | Init | Loading | Reloading (Error _) | Complete (Error _) -> React.null
                      | Reloading (Ok _) | Complete (Ok _) ->
                        Link.Button.make ~disabled:(follow |> Async_result.isBusy)
                          ~className:
                            ( match follow with
                            | Init | Loading | Reloading (_, false) | Complete (_, false) ->
                              "btn btn-sm btn-outline-secondary action-btn"
                            | Reloading (_, true) | Complete (_, true) -> "btn btn-sm btn-secondary action-btn"
                            )
                          ~onClick:
                            ( match follow, user with
                            | Init, (Some _ | None) | Loading, (Some _ | None) | Reloading (_, _), (Some _ | None) ->
                              Link.customFn ignore
                            | Complete (username, _), user ->
                              Option.bind user (fun (ok : Shape.user) ->
                                if ok.username = username then Some (Link.settings |> Link.location) else None
                              )
                              |> Option.value ~default:onFollowClick
                            )
                          ~children:
                            [
                              ( match follow, user with
                              | Init, (Some _ | None) ->
                                i
                                  [|
                                    className "ion-plus-round";
                                    Prop.style React.Dom.Style.(make [| marginRight "3px" |]);
                                  |]
                                  []
                              | Loading, (Some _ | None) | Reloading (_, _), _ ->
                                i
                                  [|
                                    className "ion-load-a"; Prop.style React.Dom.Style.(make [| marginRight "3px" |]);
                                  |]
                                  []
                              | Complete (username, _following), user ->
                                Option.bind user (fun (ok : Shape.user) ->
                                  if ok.username = username then
                                    Some
                                      (i
                                         [|
                                           className "ion-gear-a";
                                           Prop.style React.Dom.Style.(make [| marginRight "3px" |]);
                                         |]
                                         []
                                      )
                                  else None
                                )
                                |> Option.value
                                     ~default:
                                       (i
                                          [|
                                            className "ion-plus-round";
                                            Prop.style React.Dom.Style.(make [| marginRight "3px" |]);
                                          |]
                                          []
                                       )
                              );
                              ( match follow, user with
                              | Init, (Some _ | None) | Loading, (Some _ | None) -> "..." |> React.string
                              | Reloading (username, following), user | Complete (username, following), user ->
                                Option.bind user (fun (ok : Shape.user) ->
                                  if ok.username = username then Some "Edit Profile Settings" else None
                                )
                                |> Option.value
                                     ~default:(" " ^ (if following then "Unfollow" else "Follow") ^ " " ^ username)
                                |> React.string
                              );
                            ]
                          ()
                      );
                    ];
                ];
            ];
        ];
      div
        [| className "container" |]
        [
          div
            [| className "row" |]
            [
              div
                [| className "col-xs-12 col-md-10 offset-md-1" |]
                [
                  div
                    [| className "articles-toggle" |]
                    [
                      ul
                        [| className "nav nav-pills outline-active" |]
                        [
                          li
                            [| className "nav-item" |]
                            [
                              Link.make
                                ~className:
                                  ( match viewMode with
                                  | Shape.Profile.Author _ -> "nav-link active"
                                  | Favorited _ -> "nav-link"
                                  )
                                ~onClick:
                                  (Link.availableIf
                                     ((not isArticlesBusy)
                                     &&
                                     match viewMode with
                                     | Author _ -> false
                                     | Favorited _ -> true
                                     )
                                     (Link.Location (Link.profile ~username))
                                  )
                                ~children:[ "My Articles" |> React.string ]
                                ();
                            ];
                          li
                            [| className "nav-item" |]
                            [
                              Link.make
                                ~className:
                                  ( match viewMode with
                                  | Shape.Profile.Author _ -> "nav-link"
                                  | Favorited _ -> "nav-link active"
                                  )
                                ~onClick:
                                  (Link.availableIf
                                     ((not isArticlesBusy)
                                     &&
                                     match viewMode with
                                     | Author _ -> true
                                     | Favorited _ -> false
                                     )
                                     (Link.Location (Link.favorited ~username))
                                  )
                                ~children:[ "Favorited Articles" |> React.string ]
                                ();
                            ];
                          ( if articles |> Async_result.isBusy then li [| className "nav-item" |] [ Spinner.make () ]
                          else React.null
                          );
                        ];
                    ];
                  ( match articles with
                  | Init | Loading -> React.null
                  | Reloading (Error _) | Complete (Error _) -> "ERROR" |> React.string
                  | Reloading (Ok ok) | Complete (Ok ok) ->
                    fragment
                      [
                        fragment
                          (ok.articles
                          |> Array.to_list
                          |> List.map (fun (article : Shape.article_response) ->
                               let isFavoriteBusy = toggleFavoriteBusy |> fun __x -> Hook.SS.mem article.slug __x in
                               div
                                 [| className "article-preview"; key article.slug |]
                                 [
                                   div
                                     [| className "article-meta" |]
                                     [
                                       Link.make
                                         ~onClick:(Link.profile ~username:article.author.username |> Link.location)
                                         ~children:
                                           [
                                             ( match article.author.image with
                                             | "" -> img [||] []
                                             | src -> img [| Prop.src src |] []
                                             );
                                           ]
                                         ();
                                       div
                                         [| className "info" |]
                                         [
                                           Link.make ~className:"author"
                                             ~onClick:(Link.profile ~username:article.author.username |> Link.location)
                                             ~children:[ article.author.username |> React.string ]
                                             ();
                                           span
                                             [| className "date" |]
                                             [ article.createdAt |> Utils.formatDate |> React.string ];
                                         ];
                                       Link.Button.make
                                         ~className:
                                           ( if article.favorited then "btn btn-primary btn-sm pull-xs-right"
                                           else "btn btn-outline-primary btn-sm pull-xs-right"
                                           )
                                         ~disabled:isFavoriteBusy
                                         ~onClick:
                                           (Link.customFn (fun () ->
                                              onToggleFavorite
                                                ~action:
                                                  ( if article.favorited then Api.Action.Unfavorite article.slug
                                                  else Api.Action.Favorite article.slug
                                                  )
                                            )
                                           )
                                         ~children:
                                           [
                                             i
                                               [|
                                                 className (if isFavoriteBusy then "ion-load-a" else "ion-heart");
                                                 Prop.style React.Dom.Style.(make [| marginRight "3px" |]);
                                               |]
                                               [];
                                             article.favoritesCount |> string_of_int |> React.string;
                                           ]
                                         ();
                                     ];
                                   Link.make ~className:"preview-link"
                                     ~onClick:(Link.article ~slug:article.slug |> Link.location)
                                     ~children:
                                       [
                                         h1 [||] [ article.title |> React.string ];
                                         p [||] [ article.description |> React.string ];
                                         span [||] [ "Read more..." |> React.string ];
                                         ( match article.tagList with
                                         | [] -> React.null
                                         | tagList ->
                                           ul
                                             [| className "tag-list" |]
                                             (tagList
                                             |> List.map (fun tag ->
                                                  li
                                                    [| key tag; className "tag-default tag-pill tag-outline" |]
                                                    [ tag |> React.string ]
                                                )
                                             )
                                         );
                                       ]
                                     ();
                                 ]
                             )
                          );
                        Pagination.make ~limit ~offset ~total:ok.articlesCount
                          ~onClick:(if articles |> Async_result.isBusy then ignore else changeOffset)
                          ();
                      ]
                  );
                ];
            ];
        ];
    ]
