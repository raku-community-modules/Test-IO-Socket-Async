use Method::Protected:ver<0.0.4+>:auth<zef:lizmat>;

class Test::IO::Socket::Async {
    role Connection {
        has @!sent;
        has @!waiting-sent-vows;
        has $!received = Supplier.new;

        method print(Str() $s) {
            @!sent.push($s);
            self!keep-sent-vows();
            self!kept-promise();
        }

        method write(Blob $b) {
            @!sent.push($b);
            self!keep-sent-vows();
            self!kept-promise();
        }

        method sent-data() {
            my $p = Promise.new;
            @!waiting-sent-vows.push($p.vow);
            self!keep-sent-vows();
            $p
        }

        method !keep-sent-vows() {
            while all(@!sent, @!waiting-sent-vows) {
                @!waiting-sent-vows.shift.keep(@!sent.shift);
            }
        }

        method !kept-promise() {
            my $p = Promise.new;
            $p.keep(True);
            $p
        }

        method Supply() {
            $!received.Supply
        }

        multi method receive-data(Str() $data) {
            $!received.emit($data);
        }
        multi method receive-data(Blob $data) {
            $!received.emit($data);
        }
    }

    class ClientConnection does Connection {
        has $.host;
        has $.port;
        has $.connection-promise = Promise.new;
        has $!connection-vow = $!connection-promise.vow;

        method accept-connection() is protected {
            $!connection-vow.keep(self);
        }

        method deny-connection($exception = "Connection refused") is protected {
            $!connection-vow.break($exception);
        }
    }

    class ServerConnection does Connection {
    }

    class Listener {
        has $.host;
        has $.port;
        has $.is-closed = Promise.new;
        has $!is-closed-vow = $!is-closed.vow;
        has $!connection-supplier = Supplier.new;
        has $.connection-supply = $!connection-supplier
            .Supply
            .on-close({ $!is-closed-vow.keep(True) });

        method incoming-connection() {
            my $conn = ServerConnection.new;
            $!connection-supplier.emit($conn);
            $conn
        }
    }

    has @!waiting-connects;
    has @!waiting-connection-made-vows;
    has @!waiting-listens;
    has @!waiting-start-listening-vows;

    method connect(Str() $host, Int() $port) is protected {
        my $conn = ClientConnection.new(:$host, :$port);
        with @!waiting-connection-made-vows.shift {
            .keep($conn);
        }
        else {
            @!waiting-connects.push($conn);
        }
        $conn.connection-promise
    }

    method connection-made() is protected {
        my $p = Promise.new;
        with @!waiting-connects.shift {
            $p.keep($_);
        }
        else {
            @!waiting-connection-made-vows.push($p.vow);
        }
        $p
    }

    method listen(Str() $host, Int() $port) is protected {
        my $listener = Listener.new(:$host, :$port);
        with @!waiting-start-listening-vows.shift {
            .keep($listener);
        }
        else {
            @!waiting-listens.push($listener);
        }
        $listener.connection-supply
    }

    method start-listening() is protected {
        my $p = Promise.new;
        with @!waiting-listens.shift {
            $p.keep($_);
        }
        else {
            @!waiting-start-listening-vows.push($p.vow);
        }
        $p
    }
}

# vim: expandtab shiftwidth=4
