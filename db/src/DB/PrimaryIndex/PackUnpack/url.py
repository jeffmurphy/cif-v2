import struct

class url(object):
    """

    
    """
    def __init__ (self, debug):
        self.debug = debug

    @staticmethod
    def pack(unpacked):
        """
        Given an url (string), pack it so that it can be included in a rowkey
        The rowkey packed format is: a string
        """

        return str(unpacked)
    
    @staticmethod
    def unpack(packed):
        """
        The rowkey packed format is: a string
        The unpacked format is: a string
        """
        
        return str(packed)
    