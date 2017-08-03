# A Song of Data and GraphQL

Creating a Neo4j Graph Database (and more) based on Game of Thrones (A Song of Ice and Fire) data.

As season 7 is progressing, interest around Game of Thrones data is flaring up again.
There are plenty of very thorough data sources like the [A Wiki of Ice and Fire](http://awoiaf.westeros.org/) and the [Wikia Section of Game of Thrones](http://gameofthrones.wikia.com).
But those are unfortunately not available as plain data APIs.

Thanks to [Joakim Skoog](https://twitter.com/j_skoog) that changed at least a bit. He scraped and cleaned data from the sources above and made it available at his [An API of Ice and Fire](https://anapioficeandfire.com/About), which is a neat .Net project running on Azure. The code and data!! is also available in his [GitHub repository](https://github.com/joakimskoog/AnApiOfIceAndFire).

Most recently, Wall Street Journal wrote about his API, which I find quite unexpected.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">&#39;Game of Thrones&#39; fans are getting obsessive over data<a href="https://t.co/ImY1rWJQuO">https://t.co/ImY1rWJQuO</a></p>&mdash; Wall Street Journal (@WSJ) <a href="https://twitter.com/WSJ/status/885192072952676353">July 12, 2017</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

As we currently have our [7 weeks of Graph of Thrones challenge](https://neo4j.com/blog/graph-of-thrones/) running, I thought it would be fun and useful to create a [Neo4j](http://neo4j.com/developer) graph database out of Joakims data.

You can find all the scripts and documentation in my [game-of-graphs GitHub repository](https://github.com/neo4j-examples/game-of-graphs)

## Data Source

The data about Westeros is available via several API endpoints, which are detailed in the  [documentation](https://anapioficeandfire.com/Documentation). For us the **house** and **character** data is most interesting.

You can retrieve the data directly on the API homepage or in your browser, e.g. using https://anapioficeandfire.com/api/characters/1303 for "Daenerys Targaryen".

My initial approach used the API to retrieve the data and build the graph in Neo4j until I saw that the  [repository](https://github.com/joakimskoog/AnApiOfIceAndFire/blob/master/data) contains the original JSON files, so we can use them directly.

* https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json
* https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json

I want to make the data available both directly in Neo4j as well as an GraphQL endpoint.
That's why, using the API documentation, I wrote a short GraphQL schema file that contained people, houses, seats, and regions.

## GraphQL Setup

### Schema

See [got-schema.graphql](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-schema.graphql)

```
type Seat {
   name: String!
   houses: [House] @relation(name:"SEAT_OF")
}

type Region {
   name: String
   houses: [House] @relation(name:"IN_REGION", direction:IN)
}
type House {
   id: ID!
   name: String!
   founded: String
   titles: [String]
   ancestralWeapons: [String]
   coatOfArms: String
   words: String
   seats: [Seat] @relation(name:"SEAT_OF",direction:IN)
   region: Region @relation(name:"IN_REGION")
   leader: Person @relation(name:"LED_BY")
   founder: Person @relation(name:"FOUNDED_BY")
   allies: [House] @relation(name:"ALLIED_WITH", direction:IN)
   follows: House @relation(name:"SWORN_TO")
   followers: [House] @relation(name:"SWORN_TO",direction:IN)
   heir: [Person] @relation(name:"HEIR_TO",direction:IN)
}
type Person {
   id: ID!
   name: String!
   aliases: [String]
   books: [Int]
   tvSeries: [String]
   playedBy: [String]
   isFemale: Boolean
   culture: String
   died: String
   titles: [String]
   founded: [House] @relation(name:"FOUNDED_BY", direction:IN)
   leads: [House] @relation(name:"LED_BY", direction:IN)
   inherits: [House] @relation(name:"HEIR_TO")
   spouse: [Person] @relation(name:"SPOUSE",direction:BOTH)
   parents: [Person] @relation(name:"PARENT_OF",direction:IN)
   children: [Person] @relation(name:"PARENT_OF")
   houses: [House] @relation(name:"ALLIED_WITH")
}
```

Using the neo4j-graphql-cli, we can quickly spin up a sandbox instance for the data and push our schema file.

```
npm install -g neo4j-graphql-cli
neo4j-graphql got-schema.graphql
```

In the Neo4j UI we can display the graphql schema visually

![](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-graphql-schema.jpg)

we can do the same in GraphQL Voyager:

![](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-graphql-schema-voyager.jpg)

## Data Import

The data import works by loading the JSON files from Joakims repository with Neo4j's Cypher and creating nodes and relationships to form our graph. Because I didn't want to store and superfluous data, I use a few cleanup operations upfront. Several of the attributes are turned into relationships, e.g. leader- and followship or seats and regions.

Here are the two queries that you can just paste into the hosted Neo4j Browser of your Sandbox instance.

```
// create People and their relationships
call apoc.load.jsonArray('https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json') yield value
// cleanup
with apoc.map.clean(apoc.convert.toMap(value), [],['',[''],[],null]) as data

// lowercase keys
with apoc.map.fromPairs([k in keys(data) | [toLower(substring(k,0,1))+substring(k,1,length(k)), data[k]]]) as data

// create person
MERGE (p:Person {id:data.id}) 
// set attributes
SET 
p += apoc.map.clean(data, ['allegiances','father','spouse','mother'],[]), 
p.name = coalesce(p.name,head(p.aliases))

// create relationships to other people or houses
FOREACH (id in data.allegiances | MERGE (h:House {id:id}) MERGE (p)-[:ALLIED_WITH]->(h))
FOREACH (id in case data.father when null then [] else [data.father] end | MERGE (o:Person {id:id}) MERGE (o)-[:PARENT_OF {type:'father'}]->(p))
FOREACH (id in case data.mother when null then [] else [data.mother] end | MERGE (o:Person {id:id}) MERGE (o)-[:PARENT_OF {type:'mother'}]->(p))
FOREACH (id in case data.spouse when null then [] else [data.spouse] end | MERGE (o:Person {id:id}) MERGE (o)-[:SPOUSE]-(p))
return p.id, p.name;

// create Houses and their relationships
call apoc.load.jsonArray('https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json') yield value
// cleanup
with apoc.map.clean(apoc.convert.toMap(value), [],['',[''],[],null]) as data
// lowercase keys
with apoc.map.fromPairs([k in keys(data) | [toLower(substring(k,0,1))+substring(k,1,length(k)), data[k]]]) as data

// create House
MERGE (h:House {id:data.id}) 
// set attributes
SET 
h += apoc.map.clean(data, ['overlord','swornMembers','currentLord','heir','founder','cadetBranches'],[])

// create relationships to people or other houses
FOREACH (id in data.swornMembers | MERGE (o:Person {id:id}) MERGE (o)-[:ALLIED_WITH]->(h))
FOREACH (s in data.seats | MERGE (seat:Seat {name:s}) MERGE (seat)-[:SEAT_OF]->(h))
FOREACH (id in data.cadetBranches | MERGE (b:House {id:id}) MERGE (b)-[:BRANCH_OF]->(h))
FOREACH (id in case data.overlord when null then [] else [data.overlord] end | MERGE (o:House {id:id}) MERGE (h)-[:SWORN_TO]->(o))
FOREACH (id in case data.currentLord when null then [] else [data.currentLord] end | MERGE (o:Person {id:id}) MERGE (h)-[:LED_BY]->(o))
FOREACH (id in case data.founder when null then [] else [data.founder] end | MERGE (o:Person {id:id}) MERGE (h)-[:FOUNDED_BY]->(o))
FOREACH (id in case data.heir when null then [] else [data.heir] end | MERGE (o:Person {id:id}) MERGE (o)-[:HEIR_TO]->(h))
FOREACH (r in case data.region when null then [] else [data.region] end | MERGE (o:Region {name:r}) MERGE (h)-[:IN_REGION]->(o))
return h.id, h.name;
```

![](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-graph.jpg)

## Queries

You can query the data now via GraphQL, e.g. using the *GraphiQL* UI hosted by the sandbox. The nice thing here is that you get built in auto-completion and documentation.

### Example GraphQL Query

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

![](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-graphiql.jpg)

Of course you can use the API also from your own application or other tools (like graphql-cli).

In the sandbox you can find these instructions:

> Your GraphQL endpoint is available at `https://<10-0-1-...-.....>.neo4jsandbox.com/graphql/`. We use HTTP Basic Auth, so be sure to set an auth header: `Authorization: Basic xYXcXCCXCXCXCXCXCXCXCXCX=`

### Example Cypher queries

In the Neo4j Browser you can run arbitrary graph queries, for instance to visualize family trees.

```
MATCH path = (p:Person {name:"Steffon Baratheon"})-[:PARENT_OF*]->()
RETURN path
```

![](http://github.com/neo4j-examples/game-of-graphs/tree/master/got-cypher-parents.jpg)

### Missing Data

While looking at the data, I saw that some of it was missing, here is for instance a query that shows which main characters have no parental relationship:

```
MATCH (p:Person)
WHERE size(p.tvSeries) > 1
AND NOT exists((p)-[:PARENT_OF]-())
RETURN p LIMIT 10;
```

```
╒═════════════════╕
│"p.name"         │
╞═════════════════╡
│"Walder"         │
├─────────────────┤
│"The waif"       │
├─────────────────┤
│"High Septon"    │
├─────────────────┤
│"Margaery Tyrell"│
├─────────────────┤
│"Tywin Lannister"│
├─────────────────┤
│"Unella"         │
├─────────────────┤
│"Aemon Targaryen"│
├─────────────────┤
│"Alliser Thorne" │
├─────────────────┤
│"Arya Stark"     │
├─────────────────┤
│"Asha Greyjoy"   │
└─────────────────┘
```

You clearly see that several of them actually have parents or children, so that's missing in the data and we should help Joakim improve the data quality by sending updates his way.

## Other Datasources

Besides all the visual artists who manually crafted infographics, family networks and maps of Westeros, here are a number of graph related articles, that discuss the data side of things.

* [Network of Thrones](https://networkofthrones.wordpress.com/) by Andrew Beveridge, Character interactions
* William Lyon [Import and Analytics of the above into Neo4j](http://www.lyonwj.com/2016/06/26/graph-of-thrones-neo4j-social-network-analysis/) `:play https://guides.neo4j.com/got`
* Wikia Data via Mark Needham [Repository](https://github.com/mneedham/neo4j-got): `:play https://guides.neo4j.com/got_wwc`
* Tomaz Bratanic [Battles from Kaggle data](https://tbgraph.wordpress.com/?s=Game+of+Thrones)
* Chris Willemsen, [NLP Analytics on GoT Books](https://graphaware.com/neo4j/2017/07/24/reverse-engineering-book-stories-nlp.html)
