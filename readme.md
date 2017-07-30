# Game of Graphs

Creating a Neo4j Graph Database (and more) based on Game of Thrones (A Song of Ice and Fire) data.

## Data Source

Westeros data can be retrieved from [An API of Ice And Fire](https://anapioficeandfire.com/Documentation) by Joakim Skoog.

The [repository](https://github.com/joakimskoog/AnApiOfIceAndFire) contains the original JSON files, so we can use them directly.

* https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json
* https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json

## GraphQL Setup

### Schema

See [got-schema.graphql](./got-schema.graphql)

![](./got-graphql-schema.jpg)

* Person (name, titles, houses, ...)
* House (name, allies, follows, followers, founder, words, ...)
* Seat (name)
* Region (name)

Spin up a Neo4j Sandbox with the data and push our schema file.

```
npm install -g neo4j-graphql-cli
neo4j-graphql got-schema.graphql
```

## Data Import

Either run the content of the import scripts `got-import.cypher` in Neo4j Browser or via cypher-shell

```
# one of these
apt-get install cypher-shell

brew install cypher-shell

# and then
cypher-shell -a bolt://<sandbox-ip>:<bolt-port> -u neo4j -p <password> < got-import.cypher

# or using Docker

docker run -ti -p `pwd`:/import neo4j /bin/sh -c '/var/lib/neo4j/bin/cypher-shell -a bolt://<sandbox-ip>:<bolt-port> -u neo4j -p <password> < /import/got-import.cypher'
```

![](./got-graph.jpg)

## Queries

Via GraphiQL, instructions below copied from Neo4j Sandbox:

1. Your GraphQL endpoint is available at `https://<10-0-1-...-.....>.neo4jsandbox.com/graphql/`. We use HTTP Basic Auth, so be sure to set an auth header: `Authorization: Basic xYXcXCCXCXCXCXCXCXCXCXCX=`

2. Explore your GraphQL API with our hosted `GraphiQL IDE`.

Example GraphQL Query

```
{
  House(name: "House Stark of Winterfell") {
    name
    words
    founder {
      name
    }
    seats {
      name
    }
    region {
      name
    }
    follows {
      name
    }
    followers(first:10) {
      name
      seats { name }
    }
  }
}
```

![](./got-graphiql.jpg)

3.  Visit the `Neo4j Browser`. You'll automatically be authenticated. 

Example Cypher queries:

```
MATCH path = (p:Person {name:"Steffon Baratheon"})-[:PARENT_OF*]->()
RETURN path
```

![](./got-cypher-parents.jpg)

## Other Datasources

* [Network of Thrones](https://networkofthrones.wordpress.com/) by Andrew Beveridge, Character interactions
* William Lyon [Import and Analytics of the above into Neo4j](http://www.lyonwj.com/2016/06/26/graph-of-thrones-neo4j-social-network-analysis/) `:play https://guides.neo4j.com/got`
* Wikia Data via Mark Needham [Repository](https://github.com/mneedham/neo4j-got): `:play https://guides.neo4j.com/got_wwc`
* Tomaz Bratanic [Battles from Kaggle data](https://tbgraph.wordpress.com/?s=Game+of+Thrones)
* Chris Willemsen, [NLP Analytics on GoT Books](https://graphaware.com/neo4j/2017/07/24/reverse-engineering-book-stories-nlp.html)