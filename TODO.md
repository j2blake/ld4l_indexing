Indexing:

Bookmark scheme similar to described in ld4l_liknk_data_server, stored in search index?

But this means we need some way to iterate from last instance to first work, etc.
Write a wrapper for URI_discoverer that will progress through the types, each time returning the type and the URI

How do we generalize this? If we wanted to add another type, how can we do it in one place?
Where should BATCH_SIZE be? Could it be provided as a parameter?