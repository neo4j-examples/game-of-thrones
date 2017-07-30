create constraint on (p:Person) assert p.id is unique;
create constraint on (h:House) assert h.id is unique;
create index on :Person(name);
create index on :House(name);
create index on :Seat(name);
create index on :Region(name);

call apoc.load.jsonArray('https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json') yield value
with apoc.convert.toMap(value) as data
with apoc.map.clean(data, [],['',[''],[],null]) as data
with apoc.map.fromPairs([k in keys(data) | [toLower(substring(k,0,1))+substring(k,1,length(k)), data[k]]]) as data
MERGE (p:Person {id:data.id}) 
SET 
p += apoc.map.clean(data, ['allegiances','father','spouse','mother'],['',[''],[],null]), 
p.name = coalesce(p.name,head(p.aliases))
FOREACH (id in data.allegiances | MERGE (h:House {id:id}) MERGE (p)-[:ALLIED_WITH]->(h))
FOREACH (id in case data.father when null then [] else [data.father] end | MERGE (o:Person {id:id}) MERGE (o)-[:PARENT_OF {type:'father'}]->(p))
FOREACH (id in case data.mother when null then [] else [data.mother] end | MERGE (o:Person {id:id}) MERGE (o)-[:PARENT_OF {type:'mother'}]->(p))
FOREACH (id in case data.spouse when null then [] else [data.spouse] end | MERGE (o:Person {id:id}) MERGE (o)-[:SPOUSE]-(p))
return p.id, p.name;

call apoc.load.jsonArray('https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json') yield value
with apoc.convert.toMap(value) as data
with apoc.map.clean(data, [],['',[''],[],null]) as data
with apoc.map.fromPairs([k in keys(data) | [toLower(substring(k,0,1))+substring(k,1,length(k)), data[k]]]) as data
MERGE (h:House {id:data.id}) 
SET 
h += apoc.map.clean(data, ['overlord','swornMembers','currentLord','heir','founder','cadetBranches'],['',[''],[],null])
FOREACH (id in data.swornMembers | MERGE (o:Person {id:id}) MERGE (o)-[:ALLIED_WITH]->(h))
FOREACH (s in data.seats | MERGE (seat:Seat {name:s}) MERGE (seat)-[:SEAT_OF]->(h))
FOREACH (id in data.cadetBranches | MERGE (b:House {id:id}) MERGE (b)-[:BRANCH_OF]->(h))
FOREACH (id in case data.overlord when null then [] else [data.overlord] end | MERGE (o:House {id:id}) MERGE (h)-[:SWORN_TO]->(o))
FOREACH (id in case data.currentLord when null then [] else [data.currentLord] end | MERGE (o:Person {id:id}) MERGE (h)-[:LED_BY]->(o))
FOREACH (id in case data.founder when null then [] else [data.founder] end | MERGE (o:Person {id:id}) MERGE (h)-[:FOUNDED_BY]->(o))
FOREACH (id in case data.heir when null then [] else [data.heir] end | MERGE (o:Person {id:id}) MERGE (o)-[:HEIR_TO]->(h))
FOREACH (r in case data.region when null then [] else [data.region] end | MERGE (o:Region {name:r}) MERGE (h)-[:IN_REGION]->(o))
return h.id, h.name;
