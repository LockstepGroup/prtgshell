class HelperWeb {
    static [string] createQueryString ([hashtable]$hashTable) {
        $i = 0
        $queryString = "?"
        # Sorting hashtable to make testing for proper URLs reliable.
        foreach ($hash in ($hashTable.GetEnumerator() | Sort-Object -Property Name)) {
            $i++
            $queryString += $hash.Name + "=" + [System.Web.HttpUtility]::UrlEncode($hash.Value)
            if ($i -lt $HashTable.Count) {
                $queryString += "&"
            }
        }
        return $queryString
    }
}