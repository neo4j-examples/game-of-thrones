create constraint on (p:Person) assert p.id is unique;
create constraint on (h:House) assert h.id is unique;
create index on :Person(name);
create index on :House(name);
create index on :Seat(name);
create index on :Region(name);

with 'characters' as type, 1 as page
call apoc.load.jsonArray('https://www.anapioficeandfire.com/api/'+type+'?pageSize=2&page='+page) yield value
with apoc.map.clean(value, [],['',[''],[]]) as data
return data;

with 'houses' as type, 1 as page
call apoc.load.jsonArray('https://www.anapioficeandfire.com/api/'+type+'?pageSize=2&page='+page) yield value
with apoc.map.clean(value, [],['',[''],[]]) as data
return data;


unwind range(1,43) as page
call apoc.util.sleep(1)
with page, 'characters' as type
call apoc.load.jsonArray('https://www.anapioficeandfire.com/api/'+type+'?pageSize=50&page='+page) yield value
with apoc.convert.toMap(value) as data
MERGE (p:Person {id:split(data.url,"/")[-1]}) 
SET 
p += apoc.map.clean(data, ['allegiances','books','father','spouse','mother'],['',[''],[]]), 
p.books = [b in data.books | split(b,'/')[-1]],
p.name = colaesce(p.name,head(p.aliases))
FOREACH (a in data.allegiances | MERGE (h:House {id:split(a,'/')[-1]}) MERGE (p)-[:SWORN_TO]->(h))
FOREACH (f in case coalesce(data.father,"") when "" then [] else [data.father] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (o)-[:PARENT_OF {type:'father'}]->(p))
FOREACH (f in case coalesce(data.mother,"") when "" then [] else [data.mother] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (o)-[:PARENT_OF {type:'mother'}]->(p))
FOREACH (f in case coalesce(data.spouse,"") when "" then [] else [data.spouse] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (o)-[:SPOUSE]-(p))
return p.id, p.name;

unwind range(1,9) as page
with page, 'houses' as type
call apoc.load.jsonArray('https://www.anapioficeandfire.com/api/'+type+'?pageSize=50&page='+page) yield value
with apoc.convert.toMap(value) as data
with apoc.map.clean(data, [],['',[''],[]]) as data
MERGE (h:House {id:split(data.url,"/")[-1]}) 
SET 
h += apoc.map.clean(data, ['overlord','swornMembers','currentLord','heir','founder','cadetBranches'],['',[''],[]])
FOREACH (a in data.swornMembers | MERGE (o:Person {id:split(a,'/')[-1]}) MERGE (o)-[:SWORN_TO]->(h))
FOREACH (s in data.seats | MERGE (seat:Seat {name:s}) MERGE (seat)-[:SEAT_OF]->(h))
FOREACH (c in data.cadetBranches | MERGE (b:House {id:split(c,'/')[-1]}) MERGE (b)-[:BRANCH_OF]->(h))
FOREACH (f in case coalesce(data.overlord,"") when "" then [] else [data.overlord] end | MERGE (o:House {id:split(f,'/')[-1]}) MERGE (h)-[:SWORN_TO]->(o))
FOREACH (f in case coalesce(data.currentLord,"") when "" then [] else [data.currentLord] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (h)-[:LED_BY]->(o))
FOREACH (f in case coalesce(data.founder,"") when "" then [] else [data.founder] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (h)-[:FOUNDED_BY]->(o))
FOREACH (f in case coalesce(data.heir,"") when "" then [] else [data.heir] end | MERGE (o:Person {id:split(f,'/')[-1]}) MERGE (o)-[:HEIR_TO]->(h))
FOREACH (f in case coalesce(data.region,"") when "" then [] else [data.region] end | MERGE (o:Region {name:f}) MERGE (h)-[:IN_REGION]->(o))
return h.id, h.name;


