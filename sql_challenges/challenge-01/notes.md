The way to get a value as a subquery is putting the self query between parenthesis ()
```sql
SELECT * FROM X WHERE Y > (SELECT Y FROM X WHERE Z = A)
```